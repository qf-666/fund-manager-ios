import Foundation

protocol EastMoneyAPIProtocol {
    func searchFunds(matching query: String) async throws -> [FundSearchItem]
    func fetchSnapshots(codes: [String], deviceId: String) async throws -> [RemoteFundSnapshot]
    func fetchIndices() async throws -> [MarketIndexItem]
    func fetchProfile(code: String) async throws -> FundProfile
    func fetchNetValueSeries(code: String, range: ChartRange) async throws -> [NAVPoint]
}

enum EastMoneyAPIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case invalidPayload(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let raw):
            return "无效的接口地址：\(raw)"
        case .invalidResponse:
            return "接口返回状态异常。"
        case .invalidPayload(let message):
            return "接口数据格式异常：\(message)"
        }
    }
}

struct EastMoneyAPI: EastMoneyAPIProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchFunds(matching query: String) async throws -> [FundSearchItem] {
        var components = URLComponents(string: "https://fundsuggest.eastmoney.com/FundSearch/api/FundSearchAPI.ashx")
        components?.queryItems = [
            URLQueryItem(name: "m", value: "9"),
            URLQueryItem(name: "key", value: query)
        ]
        guard let url = components?.url else {
            throw EastMoneyAPIError.invalidURL("fund search")
        }

        let object = try await request(url)
        guard let root = object as? [String: Any], let items = root["Datas"] as? [[String: Any]] else {
            throw EastMoneyAPIError.invalidPayload("搜索结果缺少 Datas")
        }

        return items.compactMap { item in
            guard let code = string(item["CODE"]), let name = string(item["NAME"]) else {
                return nil
            }
            return FundSearchItem(
                code: code,
                name: name,
                pinyin: string(item["JP"]) ?? "",
                category: string(item["CATEGORYDESC"]) ?? string(item["CATEGORY"]) ?? "基金"
            )
        }
    }

    func fetchSnapshots(codes: [String], deviceId: String) async throws -> [RemoteFundSnapshot] {
        guard !codes.isEmpty else { return [] }
        let joined = codes.joined(separator: ",")
        let rawURL = "https://fundmobapi.eastmoney.com/FundMNewApi/FundMNFInfo?pageIndex=1&pageSize=200&plat=Android&appType=ttjj&product=EFund&Version=1&deviceid=\(deviceId)&Fcodes=\(joined)"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard let root = object as? [String: Any], let items = root["Datas"] as? [[String: Any]] else {
            throw EastMoneyAPIError.invalidPayload("基金快照缺少 Datas")
        }

        return items.compactMap { item in
            guard let code = string(item["FCODE"]), let name = string(item["SHORTNAME"]) else {
                return nil
            }
            return RemoteFundSnapshot(
                code: code,
                name: name,
                nav: double(item["NAV"]),
                estimatedNav: double(item["GSZ"]),
                estimatedChangePercent: double(item["GSZZL"]),
                dailyNavChangePercent: double(item["NAVCHGRT"]),
                reportDate: string(item["PDATE"]),
                estimatedTime: string(item["GZTIME"]) ?? string(item["HQDATE"])
            )
        }
    }

    func fetchIndices() async throws -> [MarketIndexItem] {
        let rawURL = "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&fields=f2,f3,f4,f12,f13,f14&secids=1.000001,0.399001,0.399006"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard
            let root = object as? [String: Any],
            let data = root["data"] as? [String: Any],
            let diff = data["diff"] as? [[String: Any]]
        else {
            throw EastMoneyAPIError.invalidPayload("指数行情缺少 data.diff")
        }

        return diff.compactMap { item in
            guard
                let code = string(item["f12"]),
                let name = string(item["f14"]),
                let latest = double(item["f2"]),
                let change = double(item["f4"]),
                let changePercent = double(item["f3"])
            else {
                return nil
            }
            return MarketIndexItem(code: code, name: name, latest: latest, change: change, changePercent: changePercent)
        }
    }

    func fetchProfile(code: String) async throws -> FundProfile {
        let rawURL = "https://fundmobapi.eastmoney.com/FundMApi/FundBaseTypeInformation.ashx?FCODE=\(code)&deviceid=Wap&plat=Wap&product=EFund&version=2.0.0"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard let root = object as? [String: Any], let data = root["Datas"] as? [String: Any] else {
            throw EastMoneyAPIError.invalidPayload("基金详情缺少 Datas")
        }

        return FundProfile(
            code: code,
            name: string(data["SHORTNAME"]) ?? code,
            company: string(data["JJGS"]) ?? string(data["JJGSBID"]) ?? "--",
            manager: string(data["JJJL"]) ?? string(data["MANAGER"]) ?? "--",
            fundType: string(data["FTYPE"]) ?? string(data["FUNDTYPE"]) ?? "--",
            riskLevel: string(data["RISKLEVEL"]) ?? "--",
            subscriptionStatus: string(data["SGZT"]) ?? "--",
            redemptionStatus: string(data["SHZT"]) ?? "--"
        )
    }

    func fetchNetValueSeries(code: String, range: ChartRange) async throws -> [NAVPoint] {
        let rawURL = "https://fundmobapi.eastmoney.com/FundMApi/FundNetDiagram.ashx?FCODE=\(code)&RANGE=\(range.rawValue)&deviceid=Wap&plat=Wap&product=EFund&version=2.0.0"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard let root = object as? [String: Any], let rows = root["Datas"] as? [[String: Any]] else {
            throw EastMoneyAPIError.invalidPayload("净值曲线缺少 Datas")
        }

        return rows.compactMap { row in
            guard
                let rawDate = string(row["FSRQ"]),
                let date = DisplayFormatter.date(rawDate),
                let value = double(row["DWJZ"])
            else {
                return nil
            }
            return NAVPoint(date: date, value: value)
        }
        .sorted { $0.date < $1.date }
    }

    private func request(_ url: URL) async throws -> Any {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw EastMoneyAPIError.invalidResponse
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != "--" else { return nil }
            return Double(trimmed.replacingOccurrences(of: ",", with: ""))
        default:
            return nil
        }
    }
}
