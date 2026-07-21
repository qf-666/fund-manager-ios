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
        let secids = "1.000001,1.000300,0.399001,0.399006"
        let preferredOrder = ["000001", "000300", "399001", "399006"]
        let hosts = [
            "push2.eastmoney.com",
            "push2delay.eastmoney.com",
            "82.push2.eastmoney.com"
        ]

        var lastError: Error = EastMoneyAPIError.invalidResponse
        for host in hosts {
            let rawURL = "https://\(host)/api/qt/ulist.np/get?fltt=2&fields=f2,f3,f4,f12,f13,f14&secids=\(secids)"
            guard let url = URL(string: rawURL) else { continue }
            do {
                let object = try await request(url)
                guard
                    let root = object as? [String: Any],
                    let data = root["data"] as? [String: Any],
                    let diff = data["diff"] as? [[String: Any]]
                else {
                    lastError = EastMoneyAPIError.invalidPayload("缺少 data.diff")
                    continue
                }

                let items = diff.compactMap { item -> MarketIndexItem? in
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
                if !items.isEmpty {
                    return items
                }
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        throw lastError
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

        // push2 经常被掐连接：失败时仍返回持仓列表（价格/涨跌为 --），
        // 绝不能让整页持仓明细失败或冒泡成全局「网络连接已中断」。
        let quotesByCode = await fetchStockQuotes(secIDs: secIDs)

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

    /// push2 多节点重试；全部失败返回空字典，由 UI 显示 --。
    private func fetchStockQuotes(secIDs: [String]) async -> [String: [String: Any]] {
        guard !secIDs.isEmpty else { return [:] }
        let joined = secIDs.joined(separator: ",")
        let hosts = [
            "push2.eastmoney.com",
            "push2delay.eastmoney.com",
            "82.push2.eastmoney.com",
            "push2his.eastmoney.com"
        ]
        let query = "api/qt/ulist.np/get?fields=f2,f3,f4,f12,f13,f14,f292&fltt=2&secids=\(joined)&deviceid=Wap&plat=Wap&product=EFund&version=2.0.0"

        for host in hosts {
            let rawURL = "https://\(host)/\(query)"
            guard let url = URL(string: rawURL) else { continue }
            for _ in 0..<2 {
                do {
                    let object = try await request(url)
                    guard
                        let root = object as? [String: Any],
                        let data = root["data"] as? [String: Any],
                        let diff = data["diff"] as? [[String: Any]],
                        !diff.isEmpty
                    else {
                        continue
                    }
                    return Dictionary(uniqueKeysWithValues: diff.compactMap { item in
                        guard let code = string(item["f12"]) else { return nil }
                        return (code, item)
                    })
                } catch {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }
        return [:]
    }

    private func fetchFallbackEstimates(for snapshots: [RemoteFundSnapshot]) async -> [String: FundEstimateSnapshot] {
        // 对齐 choose.funds v3.4.4：
        // 1) 旧 fundgz（多数已 404）
        // 2) 新浪 getEstimateNetworthPic（插件 background 批量兜底）
        // 3) getCalcGszzl：重仓股加权 / 100 归一（popup 主路径）
        let missing = snapshots.filter { $0.estimatedNav == nil || $0.estimatedChangePercent == nil }
        guard !missing.isEmpty else { return [:] }

        var estimates: [String: FundEstimateSnapshot] = [:]

        await withTaskGroup(of: (String, FundEstimateSnapshot?).self) { group in
            for snapshot in missing {
                group.addTask {
                    if let estimate = try? await self.fetchEstimate(code: snapshot.code) {
                        return (snapshot.code, estimate)
                    }
                    if let estimate = try? await self.fetchSinaEstimate(for: snapshot) {
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

    /// 新浪估值图接口（choose.funds v3.4.4 background 使用）。
    /// 实测返回 `worth` / `worth_rate`（小数涨跌幅）/ `worth_date`。
    private func fetchSinaEstimate(for snapshot: RemoteFundSnapshot) async throws -> FundEstimateSnapshot? {
        let rawURL = "https://stock.finance.sina.com.cn/fundInfo/api/openapi.php/FdFundService.getEstimateNetworthPic?symbol=\(snapshot.code)"
        guard let url = URL(string: rawURL) else {
            throw EastMoneyAPIError.invalidURL(rawURL)
        }

        let object = try await request(url)
        guard
            let root = object as? [String: Any],
            let result = root["result"] as? [String: Any],
            let data = result["data"] as? [String: Any]
        else {
            return nil
        }

        // 兼容两种字段：
        // - 新版：worth / worth_rate / worth_date
        // - 旧版 networth[]：pre_nav2 / growthrate2 / pre_date
        var estimatedNav = double(data["worth"])
        var estimatedChangePercent = double(data["worth_rate"]).map { $0 * 100 }
        var estimatedDay = string(data["worth_date"])

        if estimatedNav == nil || estimatedChangePercent == nil,
           let rows = data["networth"] as? [[String: Any]],
           let last = rows.last
        {
            estimatedNav = estimatedNav ?? double(last["pre_nav2"]) ?? double(last["nav"])
            if estimatedChangePercent == nil {
                if let growth = double(last["growthrate2"]) {
                    estimatedChangePercent = growth * 100
                } else {
                    estimatedChangePercent = double(last["growthrate"]).map { abs($0) < 1 ? $0 * 100 : $0 }
                }
            }
            estimatedDay = estimatedDay ?? string(last["pre_date"]) ?? string(last["date"])
        }

        // 仅有涨跌幅时用净值推算估算净值
        if estimatedNav == nil, let nav = snapshot.nav, let change = estimatedChangePercent {
            estimatedNav = nav * (1 + change / 100)
        }
        if estimatedChangePercent == nil, let nav = snapshot.nav, let gsz = estimatedNav, nav > 0 {
            estimatedChangePercent = (gsz / nav - 1) * 100
        }

        guard estimatedNav != nil || estimatedChangePercent != nil else {
            return nil
        }

        let estimatedTime: String?
        if let estimatedDay {
            // worth_date 可能是 20260721
            if estimatedDay.count == 8, estimatedDay.allSatisfy(\.isNumber) {
                let y = estimatedDay.prefix(4)
                let m = estimatedDay.dropFirst(4).prefix(2)
                let d = estimatedDay.suffix(2)
                estimatedTime = "\(y)-\(m)-\(d)"
            } else {
                estimatedTime = estimatedDay
            }
        } else {
            estimatedTime = shanghaiTimestamp()
        }

        return FundEstimateSnapshot(
            code: snapshot.code,
            nav: snapshot.nav,
            estimatedNav: estimatedNav,
            estimatedChangePercent: estimatedChangePercent,
            reportDate: snapshot.reportDate,
            estimatedTime: estimatedTime
        )
    }

    /// 对齐 choose.funds v3.4.4 `getCalcGszzl` + `calcFundEstimateChange`：
    /// 重仓占比归一后加权 f3，得到估算涨跌幅 %。
    private func fetchPositionWeightedEstimate(for snapshot: RemoteFundSnapshot) async throws -> FundEstimateSnapshot? {
        guard let nav = snapshot.nav else { return nil }

        let position = try await fetchPositionSnapshot(code: snapshot.code)
        let holdings = position.holdings.filter {
            ($0.positionRatio ?? 0) > 0 && $0.changePercent != nil
        }

        // 联接基金：持仓可能是 ETFCODE，插件会再请求一次 ETF 成分
        if holdings.isEmpty {
            // fetchPositionSnapshot 已展开股票；空则放弃
            return nil
        }

        // 插件公式：sum((JZBL / totalJZBL) * f3)，不再 /100 把现金仓位摊薄。
        let totalWeight = holdings.compactMap(\.positionRatio).reduce(0, +)
        guard totalWeight > 0 else { return nil }

        var weightedChange = 0.0
        for holding in holdings {
            guard let weight = holding.positionRatio, let change = holding.changePercent else { continue }
            weightedChange += (weight / totalWeight) * change
        }

        // 覆盖持仓过少时结果不可信
        guard holdings.count >= 3 || totalWeight >= 20 else { return nil }

        let estimatedChangePercent = weightedChange
        let estimatedNav = nav * (1 + estimatedChangePercent / 100)

        return FundEstimateSnapshot(
            code: snapshot.code,
            nav: nav,
            estimatedNav: estimatedNav,
            estimatedChangePercent: estimatedChangePercent,
            reportDate: snapshot.reportDate,
            estimatedTime: shanghaiTimestamp()
        )
    }

    private func shanghaiTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
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
        // 对齐 choose.funds v3.4.4 rules.json：fundmobapi 用移动 Safari UA
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        let host = url.host?.lowercased() ?? ""
        if host.contains("sina.com.cn") {
            request.setValue("https://finance.sina.com.cn/", forHTTPHeaderField: "Referer")
        } else {
            // push2 / fundmobapi 对无 Referer 请求偶发断连
            request.setValue("https://fund.eastmoney.com/", forHTTPHeaderField: "Referer")
        }
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
