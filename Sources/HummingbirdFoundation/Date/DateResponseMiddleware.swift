import Hummingbird

/// Adds a "Date" header to every response from the server
public struct HBDateResponseMiddleware: HBPostProcessMiddleware {
    /// Initialize HBDateResponseMiddleware
    public init(application: HBApplication) {
        // the date response middleware requires that the data cache has been setup
        application.addDateCaches()
    }

    public func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        next.respond(to: request)
    }

    public func postProcess(response: HBResponse, for request: HBRequest) {
        response.headers.replaceOrAdd(name: "Date", value: request.eventLoopStorage.dateCache.currentDate)
    }
}
