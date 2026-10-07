import Foundation

/// Short, plain sentences for the alerts shown when a TV cannot be reached.
nonisolated extension TVError {
    var userMessage: String {
        switch self {
        case .unreachable:
            return "The TV did not answer. Make sure it is on and on the same Wi-Fi as this phone."
        case .timedOut:
            return "The TV took too long to answer. Please try again."
        case .refused:
            return "The TV refused the connection. Check that network control is turned on in the TV's settings."
        case .denied:
            return "The TV did not allow this phone to control it. Accept the prompt on the TV and try again."
        case .awaitingApproval:
            return "Nobody accepted the prompt on the TV in time. Please try again and accept it on the TV."
        case .notPaired:
            return "This phone is not paired with the TV yet. Pair it again."
        case .notConnected:
            return "No TV is connected."
        case .unsupported:
            return "Control for this TV is not available yet."
        case .unsupportedApps:
            return "This TV cannot open apps from here yet."
        case .appUnavailable:
            return "The TV could not open that app. Make sure it is installed on the TV."
        case .identityUnavailable:
            return "This phone could not create the certificate the TV needs. Please try again."
        default:
            return "Something went wrong talking to the TV. Please try again."
        }
    }
}

nonisolated extension PairingError {
    var userMessage: String {
        switch self {
        case .unreachable:
            return "The TV did not answer. Make sure it is on and on the same Wi-Fi as this phone."
        case .timedOut:
            return "The TV took too long to answer. Please try again."
        case .alreadyPending:
            return "The TV is already showing a code. Wait a moment, then try again."
        case .rejected:
            return "The TV refused the pairing request."
        case .badResponse:
            return "The TV answered with something this app could not read."
        case .identityUnavailable:
            return "This phone could not create the certificate the TV needs. Please try again."
        case .wrongCode:
            return "The code does not match the one on the TV."
        case .notBuilt:
            return "Pairing with this kind of TV is not available yet."
        }
    }
}
