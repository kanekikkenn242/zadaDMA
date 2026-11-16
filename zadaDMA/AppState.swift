    func startInjection(featureName: String, isOn: Bool, patchName: String? = nil) {
        guard isOn else { return }
        self.activeInjectionName = featureName
        self.injectionStep = 1
        self.injectionSuccess = false
        self.injectionError = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.injectionStep = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { self.injectionStep = 3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            self.injectionStep = 4
            
            // Kontrollojmë nëse kemi patchName
            guard let patch = patchName else {
                self.injectionError = "Patch-i nuk u specifikua."
                return
            }
            
            // Thirrasim funksionin real nga MotorBridge
            let success = MotorBridge.applyPatch(patch)
            
            DispatchQueue.main.async {
                if success {
                    self.injectionSuccess = true
                    self.patchLog.append("✅ \(featureName) u injektua.")
                } else {
                    // KY ËSHTË GABIMI REAL
                    self.injectionError = "Dështoi injektimi! iOS 27 bllokon Kernel Exploit (kfd) ose Sandbox Escape. Skedari nuk u ndryshua."
                    self.injectionSuccess = false
                    self.patchLog.append("❌ \(featureName) dështoi.")
                }
            }
        }
    }
