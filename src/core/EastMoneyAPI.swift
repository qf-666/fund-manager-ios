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

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeSession()
    }

    func searchFunds(matching query: String) async throws -> [FundSearchItem] {
        let url = try makeURL(
            host: "fundsuggest.eastmoney.com",
            path: "/FundSearch/api/FundSearchAPI.ashx",
            queryItems: [
                URLQueryItem(name: "m", value: "9"),
                URLQueryItem(name: "key", value: query)
            ]
        )

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
        let joinedCodes = joinedCodes(from: codes)
        guard !joinedCodes.isEmpty else { return [] }
        let url = try makeURL(
            host: "fundmobapi.eastmoney.com",
            path: "/FundMNewApi/FundMNFInfo",
            queryItems: [
                URLQueryItem(name: "pageIndex", value: "1"),
                URLQueryItem(name: "pageSize", value: "200"),
                URLQueryItem(name: "plat", value: "Android"),
                URLQueryItem(name: "appType", value: "ttjj"),
                URLQueryItem(name: "product", value: "EFund"),
                URLQueryItem(name: "Version", value: "1"),
                URLQueryItem(name: "deviceid", value: normalizedQueryValue(deviceId)),
                URLQueryItem(name: "Fcodes", value: joinedCodes)
            ]
        )

        let object = try await request(url)
        guard let root = object as? [String: Any], let items = root["Datas"] as? [[String: Any]] else {
            throw EastMoneyAPIError.invalidPayload("基金快照缺少 Datas")
        }

        let expansion = root["Expansion"] as? [String: Any]
        let sharedEstimatedTime = string(expansion?["GZTIME"])

        let snapshots: [RemoteFundSnapshot] = items.compactMap { item -> RemoteFundSnapshot? in
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
                estimatedTime: string(item["GZTIME"]) ?? string(item["HQDATE"]) ?? sharedEstimatedTime
            )
        }

        let fallbackEstimates = await fetchFallbackEstimates(for: snapshots)
        return snapshots.map { $0.merged(with: fallbackEstimates[$0.code]) }
    }

    func fetchIndices() async throws -> [MarketIndexItem] {
        let url = try makeURL(
            host: "push2.eastmoney.com",
            path: "/api/qt/ulist.np/get",
            queryItems: [
                URLQueryItem(name: "fltt", value: "2"),
                URLQueryItem(name: "fields", value: "f2,f3,f4,f12,f13,f14"),
                URLQueryItem(name: "secids", value: "1.000001,1.000300,0.399001,0.399006")
            ]
        )

        let object = try await request(url)
        guard
            let root = object as? [String: Any],
            let data = root["data"] as? [String: Any],
            let diff = data["diff"] as? [[String: Any]]
        else {
            throw EastMoneyAPIError.invalidPayload("指数行情缺少 data.diff")
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
        let url = try makeURL(
            host: "fundmobapi.eastmoney.com",
            path: "/FundMApi/FundBaseTypeInformation.ashx",
            queryItems: [
                URLQueryItem(name: "FCODE", value: normalizedQueryValue(code)),
                URLQueryItem(name: "deviceid", value: "Wap"),
                URLQueryItem(name: "plat", value: "Wap"),
                URLQueryItem(name: "product", value: "EFund"),
                URLQueryItem(name: "version", value: "2.0.0")
            ]
        )

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
        let url = try makeURL(
            host: "fundmobapi.eastmoney.com",
            path: "/FundMApi/FundNetDiagram.ashx",
            queryItems: [
                URLQueryItem(name: "FCODE", value: normalizedQueryValue(code)),
                URLQueryItem(name: "RANGE", value: range.rawValue),
                URLQueryItem(name: "deviceid", value: "Wap"),
                URLQueryItem(name: "plat", value: "Wap"),
                URLQueryItem(name: "product", value: "EFund"),
                URLQueryItem(name: "version", value: "2.0.0")
            ]
        )

        let object = try await request(url)
        guard let root = object as? [String: Any], let rows = root["Datas"] as? [[String: Any]] else {
            throw EastMoneyAPIError.invalidPayload("净值曲线缺少 Datas")
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
        let url = try makeURL(
            host: "fundmobapi.eastmoney.com",
            path: "/FundMNewApi/FundMNInverstPosition",
            queryItems: [
                URLQueryItem(name: "FCODE", value: normalizedQueryValue(code)),
                URLQueryItem(name: "deviceid", value: "Wap"),
                URLQueryItem(name: "plat", value: "Wap"),
                URLQueryItem(name: "product", value: "EFund"),
                URLQueryItem(name: "version", value: "2.0.0")
            ]
        )

        let object = try await request(url)
        guard let root = object as? [String: Any], let data = root["Datas"] as? [String: Any] else {
            throw EastMoneyAPIError.invalidPayload("持仓明细缺少 Datas")
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
            if let quoteURL = try? makeURL(
                host: "push2.eastmoney.com",
                path: "/api/qt/ulist.np/get",
                queryItems: [
                    URLQueryItem(name: "fields", value: "f2,f3,f4,f12,f13,f14,f292"),
                    URLQueryItem(name: "fltt", value: "2"),
                    URLQueryItem(name: "secids", value: secIDs),
                    URLQueryItem(name: "deviceid", value: "Wap"),
                    URLQueryItem(name: "plat", value: "Wap"),
                    URLQueryItem(name: "product", value: "EFund"),
                    URLQueryItem(name: "version", value: "2.0.0")
                ]
            ) {
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
        let missingEstimateCodes = snapshots
            .filter { $0.estimatedNav == nil || $0.estimatedChangePercent == nil || $0.estimatedTime == nil }
            .map(\.code)

        guard !missingEstimateCodes.isEmpty else { return [:] }

        var estimates: [String: FundEstimateSnapshot] = [:]
        for code in missingEstimateCodes {
            if let estimate = try? await fetchEstimate(code: code) {
                estimates[estimate.code] = estimate
            }
        }
        return estimates
    }

    // fallback source kept aligned with plugin: https://fundgz.1234567.com.cn/js/{code}.js
    private func fetchEstimate(code: String) async throws -> FundEstimateSnapshot? {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let url = try makeURL(
            host: "fundgz.1234567.com.cn",
            path: "/js/\(normalizedPathSegment(code)).js",
            queryItems: [URLQueryItem(name: "rt", value: String(timestamp))]
        )

        let body = try await requestText(url)
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

        return FundEstimateSnapshot(
            code: parsedCode,
            nav: double(object["dwjz"]),
            estimatedNav: double(object["gsz"]),
            estimatedChangePercent: double(object["gszzl"]),
            reportDate: string(object["jzrq"]),
            estimatedTime: string(object["gztime"])
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

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.connectionProxyDictionary = [:]
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
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
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        return request
    }

    private func makeURL(host: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = queryItems
        guard let url = components.url else {
            throw EastMoneyAPIError.invalidURL("https://\(host)\(path)")
        }
        return url
    }

    private func joinedCodes(from codes: [String]) -> String {
        codes
            .map(normalizedQueryValue)
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }

    private func normalizedQueryValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedPathSegment(_ value: String) -> String {
        normalizedQueryValue(value)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private func string(_ value: Any?) -> String? {
        switch value {
        case let string as NSString:
            let trimmed = String(string).trimmingCharacters(in: .whitespacesAndNewlines)
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
        case let string as NSString:
            let trimmed = String(string).trimmingCharacters(in: .whitespacesAndNewlines)
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
