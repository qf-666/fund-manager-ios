import Foundation

protocol EastMoneyAPIProtocol {
    func searchFunds(matching query: String) async throws -> [FundSearchItem]
    func fetchSnapshots(codes: [String], deviceId: String) async throws -> [RemoteFundSnapshot]
    func fetchIndices() async throws -> [MarketIndexItem]
    func fetchProfile(code: String) async throws -> FundProfile
    func fetchNetValueSeries(code: String, range: ChartRange) async throws -> [NAVPoint]
    func fetchPositionSnapshot(code: String) async throws -> FundPositionSnapshot
}

enum EastMoneyAPIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case invalidPayload(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let raw):
            return "????????\(raw)"
        case .invalidResponse:
            return "?????????"
        case .invalidPayload(let message):
            return "?????????\(message)"
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
            throw EastMoneyAPIError.invalidPayload("?????? Datas")
        }

        return items.compactMap { item in
            guard let code = string(item["CODE"]), let name = string(item["NAME"]) else {
                return nil
            }
            return FundSearchItem(
                code: code,
                name: name,
                pinyin: string(item["JP"]) ?? "",
                category: string(item["CATEGORYDESC"]) ?? string(item["CATEGORY"]) ?? "??"
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
            throw EastMoneyAPIError.invalidPayload("?????? Datas")
        }

        // Expansion.GZTIME 在估值接口降级时仍可能返回“今天”的日期字符串，
        // 但 Datas[].GSZ/GSZZL 为空。只有条目本身带有估值字段时，才回退用它。
        let expansion = root["Expansion"] as? [String: Any]
        let sharedEstimatedTime = string(expansion?["GZTIME"])

        let snapshots: [RemoteFundSnapshot] = items.compactMap { item -> RemoteFundSnapshot? in
            guard let code = string(item["FCODE"]), let name = string(item["SHORTNAME"]) else {
                return nil
            }

            let estimatedNav = double(item["GSZ"])
            let estimatedChangePercent = double(item["GSZZL"])
            let itemEstimatedTime = string(item["GZTIME"]) ?? string(item["HQDATE"])
            let hasEstimate = estimatedNav != nil || estimatedChangePercent != nil

            return RemoteFundSnapshot(
                code: code,
                name: name,
                nav: double(item["NAV"]),
                estimatedNav: estimatedNav,
                estimatedChangePercent: estimatedChangePercent,
                dailyNavChangePercent: double(item["NAVCHGRT"]),
                reportDate: string(item["PDATE"]),
                // 无估值数据时不要写入 shared GZTIME，否则会误判“有估值日”。
                estimatedTime: hasEstimate ? (itemEstimatedTime ?? sharedEstimatedTime) : itemEstimatedTime
            )
        }

        let fallbackEstimates = await fetchFallbackEstimates(for: snapshots)
        return snapshots.map { $0.merged(with: fallbackEstimates[$0.code]) }
    }

    func fetchIndices() async throws -> [MarketIndexItem] {
        let rawURL = "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&fields=f2,f3,f4,f12,f13,f14&secids=1.000001,1.000300,0.399001,0.399006"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard
            let root = object as? [String: Any],
            let data = root["data"] as? [String: Any],
            let diff = data["diff"] as? [[String: Any]]
        else {
            throw EastMoneyAPIError.invalidPayload("?????? data.diff")
        }

        let preferredOrder = ["000001", "000300", "399001", "399006"]

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
        .sorted { lhs, rhs in
            (preferredOrder.firstIndex(of: lhs.code) ?? .max) < (preferredOrder.firstIndex(of: rhs.code) ?? .max)
        }
    }

    func fetchProfile(code: String) async throws -> FundProfile {
        let rawURL = "https://fundmobapi.eastmoney.com/FundMApi/FundBaseTypeInformation.ashx?FCODE=\(code)&deviceid=Wap&plat=Wap&product=EFund&version=2.0.0"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard let root = object as? [String: Any], let data = root["Datas"] as? [String: Any] else {
            throw EastMoneyAPIError.invalidPayload("?????? Datas")
        }

        return FundProfile(
            code: code,
            name: string(data["SHORTNAME"]) ?? code,
            company: string(data["JJGS"]) ?? string(data["JJGSBID"]) ?? "--",
            manager: string(data["JJJL"]) ?? string(data["MANAGER"]) ?? "--",
            fundType: string(data["FTYPE"]) ?? string(data["FUNDTYPE"]) ?? "--",
            riskLevel: string(data["RISKLEVEL"]) ?? "--",
            subscriptionStatus: string(data["SGZT"]) ?? "--",
            redemptionStatus: string(data["SHZT"]) ?? "--",
            unitNAV: double(data["DWJZ"]),
            unitNAVDate: string(data["FSRQ"]),
            accumulatedNAV: double(data["LJJZ"]),
            scale: double(data["ENDNAV"]),
            oneMonthReturn: double(data["SYL_Y"]),
            oneMonthRank: rankText(value: data["RANKM"]),
            threeMonthReturn: double(data["SYL_3Y"]),
            threeMonthRank: rankText(value: data["RANKQ"]),
            sixMonthReturn: double(data["SYL_6Y"]),
            sixMonthRank: rankText(value: data["RANKHY"]),
            oneYearReturn: double(data["SYL_1N"]),
            oneYearRank: rankText(value: data["RANKY"])
        )
    }

    func fetchNetValueSeries(code: String, range: ChartRange) async throws -> [NAVPoint] {
        let rawURL = "https://fundmobapi.eastmoney.com/FundMApi/FundNetDiagram.ashx?FCODE=\(code)&RANGE=\(range.rawValue)&deviceid=Wap&plat=Wap&product=EFund&version=2.0.0"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard let root = object as? [String: Any], let rows = root["Datas"] as? [[String: Any]] else {
            throw EastMoneyAPIError.invalidPayload("?????? Datas")
        }

        return rows.compactMap { row in
            guard
                let rawDate = string(row["FSRQ"]),
                let date = DisplayFormatter.date(rawDate),
                let unitValue = double(row["DWJZ"])
            else {
                return nil
            }
            return NAVPoint(
                date: date,
                unitValue: unitValue,
                accumulatedValue: double(row["LJJZ"]),
                dailyChangePercent: double(row["JZZZL"])
            )
        }
        .sorted { $0.date < $1.date }
    }

    func fetchPositionSnapshot(code: String) async throws -> FundPositionSnapshot {
        let rawURL = "https://fundmobapi.eastmoney.com/FundMNewApi/FundMNInverstPosition?FCODE=\(code)&deviceid=Wap&plat=Wap&product=EFund&version=2.0.0"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard let root = object as? [String: Any], let data = root["Datas"] as? [String: Any] else {
            throw EastMoneyAPIError.invalidPayload("?????? Datas")
        }

        let stocks = data["fundStocks"] as? [[String: Any]] ?? []
        guard !stocks.isEmpty else {
            return FundPositionSnapshot(asOfDate: string(root["Expansion"]), holdings: [])
        }

        let secIDs = stocks.compactMap { item -> String? in
            guard let exchange = string(item["NEWTEXCH"]), let code = string(item["GPDM"]) else {
                return nil
            }
            return "\(exchange).\(code)"
        }
        .joined(separator: ",")

        var quotesByCode: [String: [String: Any]] = [:]
        if !secIDs.isEmpty {
            let quoteURLString = "https://push2.eastmoney.com/api/qt/ulist.np/get?fields=f2,f3,f4,f12,f13,f14,f292&fltt=2&secids=\(secIDs)&deviceid=Wap&plat=Wap&product=EFund&version=2.0.0"
            if let quoteURL = URL(string: quoteURLString) {
                if let quoteObject = try? await request(quoteURL),
                   let quoteRoot = quoteObject as? [String: Any],
                   let quoteData = quoteRoot["data"] as? [String: Any],
                   let diff = quoteData["diff"] as? [[String: Any]]
                {
                    quotesByCode = Dictionary(uniqueKeysWithValues: diff.compactMap { item in
                        guard let code = string(item["f12"]) else { return nil }
                        return (code, item)
                    })
                }
            }
        }

        let holdings = stocks.compactMap { item -> FundPositionHolding? in
            guard let code = string(item["GPDM"]), let name = string(item["GPJC"]) else {
                return nil
            }
            let quote = quotesByCode[code]
            return FundPositionHolding(
                code: code,
                name: name,
                latestPrice: double(quote?["f2"]),
                changePercent: double(quote?["f3"]),
                positionRatio: double(item["JZBL"]),
                changeFromPrevious: double(item["PCTNVCHG"]),
                changeFromPreviousType: string(item["PCTNVCHGTYPE"])
            )
        }

        return FundPositionSnapshot(asOfDate: string(root["Expansion"]), holdings: holdings)
    }

    private func fetchFallbackEstimates(for snapshots: [RemoteFundSnapshot]) async -> [String: FundEstimateSnapshot] {
        // fundgz.1234567.com.cn 已大面积 404，主接口 GSZ 也经常为空。
        // 对缺估值的基金：先试旧 fundgz，再按重仓股涨跌加权估算。
        let missing = snapshots.filter { $0.estimatedNav == nil || $0.estimatedChangePercent == nil }
        guard !missing.isEmpty else { return [:] }

        var estimates: [String: FundEstimateSnapshot] = [:]

        await withTaskGroup(of: (String, FundEstimateSnapshot?).self) { group in
            for snapshot in missing {
                group.addTask {
                    if let estimate = try? await self.fetchEstimate(code: snapshot.code) {
                        return (snapshot.code, estimate)
                    }
                    if let estimate = try? await self.fetchPositionWeightedEstimate(for: snapshot) {
                        return (snapshot.code, estimate)
                    }
                    return (snapshot.code, nil)
                }
            }

            for await (code, estimate) in group {
                if let estimate {
                    estimates[code] = estimate
                }
            }
        }

        return estimates
    }

    private func fetchEstimate(code: String) async throws -> FundEstimateSnapshot? {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let rawURL = "https://fundgz.1234567.com.cn/js/\(code).js?rt=\(timestamp)"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let body = try await requestText(url)
        // 接口下线后会返回 HTML 404 页，直接放弃。
        guard body.contains("fundcode") || body.contains("jsonpgz") else {
            return nil
        }
        guard
            let start = body.firstIndex(of: "("),
            let end = body.lastIndex(of: ")"),
            start < end
        else {
            return nil
        }

        let payload = String(body[body.index(after: start)..<end])
        guard
            let data = payload.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let parsedCode = string(object["fundcode"])
        else {
            return nil
        }

        let estimatedNav = double(object["gsz"])
        let estimatedChangePercent = double(object["gszzl"])
        guard estimatedNav != nil || estimatedChangePercent != nil else {
            return nil
        }

        return FundEstimateSnapshot(
            code: parsedCode,
            nav: double(object["dwjz"]),
            estimatedNav: estimatedNav,
            estimatedChangePercent: estimatedChangePercent,
            reportDate: string(object["jzrq"]),
            estimatedTime: string(object["gztime"])
        )
    }

    /// 用重仓股当日涨跌幅按持仓占比加权，近似估算净值涨跌。
    /// 仓位披露通常滞后（季报），精度不如官方估值，但在 GSZ 全空时可用。
    private func fetchPositionWeightedEstimate(for snapshot: RemoteFundSnapshot) async throws -> FundEstimateSnapshot? {
        guard let nav = snapshot.nav else { return nil }

        let position = try await fetchPositionSnapshot(code: snapshot.code)
        let holdings = position.holdings.filter {
            ($0.positionRatio ?? 0) > 0 && $0.changePercent != nil
        }
        guard !holdings.isEmpty else { return nil }

        var weightedChange = 0.0
        var coveredWeight = 0.0
        for holding in holdings {
            guard let weight = holding.positionRatio, let change = holding.changePercent else { continue }
            weightedChange += weight * change
            coveredWeight += weight
        }

        // 覆盖持仓占比过低时结果不可信（指数增强/债券/QDII 等）。
        guard coveredWeight >= 30 else { return nil }

        // weight 是占净值百分比；加权结果 /100 即基金估算涨跌幅%。
        let estimatedChangePercent = weightedChange / 100
        let estimatedNav = nav * (1 + estimatedChangePercent / 100)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let estimatedTime = formatter.string(from: Date())

        return FundEstimateSnapshot(
            code: snapshot.code,
            nav: nav,
            estimatedNav: estimatedNav,
            estimatedChangePercent: estimatedChangePercent,
            reportDate: snapshot.reportDate,
            estimatedTime: estimatedTime
        )
    }

    private func request(_ url: URL) async throws -> Any {
        let (data, _) = try await performRequest(url)
        return try JSONSerialization.jsonObject(with: data)
    }

    private func requestText(_ url: URL) async throws -> String {
        let (data, _) = try await performRequest(url)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func performRequest(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        let request = makeRequest(url)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw EastMoneyAPIError.invalidResponse
        }
        return (data, http)
    }

    private func makeRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )
        // push2 / fundmobapi 对无 Referer 请求偶发断连，对齐天天基金站内请求。
        request.setValue("https://fund.eastmoney.com/", forHTTPHeaderField: "Referer")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        return request
    }

    private func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == "--" ? nil : trimmed
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

    private func rankText(value: Any?) -> String? {
        if let text = string(value) {
            return text
        }
        if let number = double(value) {
            return String(Int(number))
        }
        return nil
    }
}
