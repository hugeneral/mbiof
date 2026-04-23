import SwiftUI
import WebKit
import HealthKit

struct ContentView: View {
    var body: some View {
        WebView()
            .edgesIgnoringSafeArea(.all)
    }
}

struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView

        // This is your EXACT live web app url
        if let url = URL(string: "https://ais-pre-yzkvxgkinxg3ey4cpexkoj-782729938450.europe-west2.run.app") {
            webView.load(URLRequest(url: url))
        }

        context.coordinator.requestHealthPermissions()

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var webView: WKWebView?
        let healthStore = HKHealthStore()

        func requestHealthPermissions() {
            guard HKHealthStore.isHealthDataAvailable(),
                  let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

            healthStore.requestAuthorization(toShare: nil, read: [hrType]) { success, _ in
                if success { self.startHeartRateQuery() }
            }
        }

        func startHeartRateQuery() {
            guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
            let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)

            let query = HKAnchoredObjectQuery(type: hrType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] (_, samples, _, _, _) in
                self?.process(samples: samples)
            }
            query.updateHandler = { [weak self] (_, samples, _, _, _) in
                self?.process(samples: samples)
            }
            healthStore.execute(query)
        }

        func process(samples: [HKSample]?) {
            guard let validSamples = samples as? [HKQuantitySample] else { return }
            for sample in validSamples {
                let hr = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                // Fire the event our web app is waiting for
                DispatchQueue.main.async {
                    let js = "window.dispatchEvent(new CustomEvent('nativeHeartRate', { detail: { hr: \(Int(hr)) } }));"
                    self.webView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }
    }
}