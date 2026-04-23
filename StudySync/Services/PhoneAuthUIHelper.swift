import UIKit
import FirebaseAuth

/// Presents the Firebase Phone Auth reCAPTCHA / verification UI. Required when APNs silent verification is unavailable (e.g. Simulator).
final class PhoneAuthUIHelper: NSObject, AuthUIDelegate {

    weak var presenter: UIViewController?

    init(presenter: UIViewController?) {
        self.presenter = presenter
    }

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.presenter?.present(viewControllerToPresent, animated: flag, completion: completion)
        }
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.presenter?.dismiss(animated: flag, completion: completion)
        }
    }
}
