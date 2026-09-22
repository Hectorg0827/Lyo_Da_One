import Foundation

// MARK: - Study plan endpoints
//
// The routes behind a study plan, mounted at /api/v1/me/study_plans.
//
// Named `TestPrepPlanService` rather than the obvious `TestPrepService`, which
// already exists and does something else entirely — calendar events and local
// notifications for an exam, with four live callers. And not
// `StudyPlanService` either: that was the name of the removed service which
// claimed to persist a learner's plan and never did, and the parity gate keeps
// that filename out so the broken one cannot return beside this one.
//
// What it replaces POSTed to "/api/v1/me/study_plans", which the server
// registers for GET only. Every call was a 405 that `try?` discarded, under a
// comment saying the plan was persisted so it would survive an app restart.
// Nothing was ever saved and nothing ever said so.
//
// A plan is not created in one POST. It is built by a conversation — `intake`
// until the server says `intake_complete`, then `generate` — and that is the
// only way any client can make one.

extension Endpoints {
    enum StudyPlans: Endpoint {
        /// This learner's plans. GET; see the note above.
        case plans
        case state
        case editProfile(id: String, body: PrepProfileUpdate)
        case intakeTurn(body: IntakeTurnRequest)
        case generatePlan(testProfileId: String)
        case readiness(planId: String)
        case todaySessions
        /// Deliberately carries no score.
        case completeSession(sessionId: String, notes: String)

        var path: String {
            switch self {
            case .plans:
                return "/api/v1/me/study_plans"
            case .state:
                return "/api/v1/me/study_plans/state"
            case .editProfile(let id, _):
                return "/api/v1/me/study_plans/profiles/\(id)"
            case .intakeTurn:
                return "/api/v1/me/study_plans/intake/turn"
            case .generatePlan:
                return "/api/v1/me/study_plans/plans/generate"
            case .readiness(let planId):
                return "/api/v1/me/study_plans/plans/\(planId)/readiness"
            case .todaySessions:
                return "/api/v1/me/study_plans/sessions/today"
            case .completeSession(let sessionId, _):
                return "/api/v1/me/study_plans/sessions/\(sessionId)/complete"
            }
        }

        var method: HTTPMethod {
            switch self {
            case .plans, .readiness, .todaySessions, .state:
                return .get
            case .editProfile:
                return .patch
            case .intakeTurn, .generatePlan, .completeSession:
                return .post
            }
        }

        var body: Encodable? {
            switch self {
            case .intakeTurn(let body):
                return body
            case .editProfile(_, let body):
                return body
            default:
                return nil
            }
        }

        var queryItems: [URLQueryItem]? {
            switch self {
            // `test_profile_id` is a query parameter, not a body field — that
            // is how the route declares it.
            case .generatePlan(let testProfileId):
                return [URLQueryItem(name: "test_profile_id", value: testProfileId)]
            case .todaySessions:
                return [URLQueryItem(name: "timezone", value: TimeZone.current.identifier)]
            case .completeSession(_, let notes):
                // `user_notes` only. The route used to take a score here — the
                // device saying how well its owner had done — and stored it as
                // the learner's performance. It now derives the outcome from
                // evidence the server itself recorded. Sending one is not
                // merely ignored: it is the thing that was wrong.
                return [URLQueryItem(name: "user_notes", value: notes)]
            default:
                return nil
            }
        }

        // A learner's own plan is never cached: readiness changes the moment
        // they finish a lesson, and a stale "you haven't started yet" is
        // exactly the false claim this surface exists to avoid.
        var cacheTTL: TimeInterval { 0 }
    }
}

/// One turn the learner types during intake.
struct IntakeTurnRequest: Codable {
    let userMessage: String
    /// nil on the opening turn; the server creates the profile and returns its id.
    let testProfileId: String?
    var timezone: String = TimeZone.current.identifier
    var requestId: String = UUID().uuidString
    var materials: [PrepMaterial] = []
}

// MARK: - Study plan service

/// Reads and writes a learner's study plan through the real routes.
///
/// Every method throws rather than returning an optional. The surface this
/// replaces swallowed every failure with `try?`, which is how a route that
/// answered 405 on every call went unnoticed for as long as it did — a failed
/// request and an empty result must not look the same to the caller.
actor TestPrepPlanService {
    static let shared = TestPrepPlanService()

    private let client: NetworkClient

    init(client: NetworkClient = .shared) {
        self.client = client
    }

    func plans() async throws -> [StudyPlanSummary] {
        try await client.request(Endpoints.StudyPlans.plans, cachePolicy: .reloadIgnoringCache)
    }

    func state() async throws -> PrepSnapshot {
        try await client.request(Endpoints.StudyPlans.state, cachePolicy: .reloadIgnoringCache)
    }

    func editProfile(id: String, body: PrepProfileUpdate) async throws -> PrepEditReply {
        try await client.request(Endpoints.StudyPlans.editProfile(id: id, body: body), cachePolicy: .reloadIgnoringCache)
    }

    func intakeTurn(message: String, testProfileId: String?, requestId: String = UUID().uuidString,
                    materials: [PrepMaterial] = []) async throws -> IntakeTurnReply {
        try await client.request(
            Endpoints.StudyPlans.intakeTurn(
                body: IntakeTurnRequest(userMessage: message, testProfileId: testProfileId,
                    requestId: requestId, materials: materials)
            ),
            cachePolicy: .reloadIgnoringCache
        )
    }

    func generatePlan(testProfileId: String) async throws -> GeneratedPlan {
        try await client.request(
            Endpoints.StudyPlans.generatePlan(testProfileId: testProfileId),
            cachePolicy: .reloadIgnoringCache
        )
    }

    func readiness(planId: String) async throws -> PlanReadiness {
        try await client.request(
            Endpoints.StudyPlans.readiness(planId: planId),
            cachePolicy: .reloadIgnoringCache
        )
    }

    func todaySessions() async throws -> [PlannedSession] {
        try await client.request(
            Endpoints.StudyPlans.todaySessions,
            cachePolicy: .reloadIgnoringCache
        )
    }

    /// Close a session out and return what the server measured.
    ///
    /// Takes no score, and has nowhere to put one.
    func completeSession(sessionId: String, notes: String = "") async throws -> SessionOutcome {
        try await client.request(
            Endpoints.StudyPlans.completeSession(sessionId: sessionId, notes: notes),
            cachePolicy: .reloadIgnoringCache
        )
    }
}
