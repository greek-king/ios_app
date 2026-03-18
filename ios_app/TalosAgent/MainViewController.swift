import UIKit

class MainViewController: UIViewController {

    private let statusLabel   = UILabel()
    private let portLabel     = UILabel()
    private let ipLabel       = UILabel()
    private let logoView      = UIImageView()
    private var statusTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startStatusUpdates()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.03, green: 0.05, blue: 0.08, alpha: 1)

        // Logo area
        let titleLabel = UILabel()
        titleLabel.text = "◉ TALOS FORENSICS"
        titleLabel.font = .systemFont(ofSize: 13, weight: .black)
        titleLabel.textColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Agent status card
        let card = UIView()
        card.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.1, alpha: 1)
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(red: 0.1, green: 0.15, blue: 0.25, alpha: 1).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        // Green dot
        let dot = UIView()
        dot.backgroundColor = UIColor(red: 0.15, green: 0.65, blue: 0.25, alpha: 1)
        dot.layer.cornerRadius = 6
        dot.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(dot)

        statusLabel.text = "Agent Running"
        statusLabel.font = .systemFont(ofSize: 18, weight: .bold)
        statusLabel.textColor = .white
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statusLabel)

        portLabel.text = "Port: 27042"
        portLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        portLabel.textColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        portLabel.textAlignment = .center
        portLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(portLabel)

        let instrLabel = UILabel()
        instrLabel.text = "Connect iPhone to computer\nTalos Forensics detects this agent\nautomatically over USB"
        instrLabel.font = .systemFont(ofSize: 13, weight: .regular)
        instrLabel.textColor = UIColor(white: 0.6, alpha: 1)
        instrLabel.textAlignment = .center
        instrLabel.numberOfLines = 0
        instrLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(instrLabel)

        let keepAliveLabel = UILabel()
        keepAliveLabel.text = "⚠ Keep this app open\nfor extractions to work"
        keepAliveLabel.font = .systemFont(ofSize: 12, weight: .medium)
        keepAliveLabel.textColor = UIColor(red: 1, green: 0.76, blue: 0, alpha: 1)
        keepAliveLabel.textAlignment = .center
        keepAliveLabel.numberOfLines = 2
        keepAliveLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keepAliveLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            card.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            dot.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            dot.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12),

            statusLabel.topAnchor.constraint(equalTo: dot.bottomAnchor, constant: 12),
            statusLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            portLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            portLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            instrLabel.topAnchor.constraint(equalTo: portLabel.bottomAnchor, constant: 20),
            instrLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            instrLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            instrLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            instrLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),

            keepAliveLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 32),
            keepAliveLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        // Pulse animation on dot
        UIView.animate(withDuration: 1.0,
                       delay: 0,
                       options: [.autoreverse, .repeat],
                       animations: { dot.alpha = 0.3 })
    }

    private func startStatusUpdates() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // Keep the server alive and update UI if needed
        }
    }

    deinit { statusTimer?.invalidate() }
}
