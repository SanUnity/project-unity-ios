//
//  QRViewController.swift
//  COVID 19 CORE
//
//  Created by Emilio Cubo Ruiz on 23/06/2020.
//  Copyright © 2020 COVID 19 CORE. All rights reserved.
//

import UIKit
import AVFoundation

protocol QRViewControllerDelegate {
    func setQRCode(_ code: String)
    func cancelQRScan()
}


class QRViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    
    var errorMessage:Bool = false

    @IBOutlet weak var scannerView: QRScannerView! {
        didSet {
            scannerView.delegate = self
        }
    }

    var delegate: QRViewControllerDelegate?
    var strCode:String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if self.errorMessage {
            titleLabel.text = NSLocalizedString("Invalid center code", comment: "")
            titleLabel.textColor = .red
        }
        
        cancelButton.layer.cornerRadius = cancelButton.bounds.height / 2
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if strCode == nil {
            delegate?.cancelQRScan()
        }
    }
    
    @IBAction func cancelScan(_ sender: UIButton) {
        strCode = nil
        self.dismiss(animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension QRViewController: QRScannerViewDelegate {
    
    func isValid(_ qr:String) -> Bool {
        return true
    }
    
    func qrScanningDidFail() {}
    
    func qrScanningSucceededWithCode(_ str: String?) {
        if let str = str {
            if self.isValid(str) {
                self.strCode = str
                scannerView.stopScanning()
                self.titleLabel.text = NSLocalizedString("Read the center QR Code", comment: "")
                if #available(iOS 13.0, *) {
                    self.titleLabel.textColor = .label
                } else {
                    self.titleLabel.textColor = .black
                }
                self.dismiss(animated: true) {
                    self.delegate?.setQRCode(str)
                }
            } else {
                self.strCode = nil
                self.errorMessage = true
                self.titleLabel.text = NSLocalizedString("Invalid center code", comment: "")
                self.titleLabel.textColor = .red
            }
        } else {
            self.strCode = nil
        }
    }
    
    func qrScanningDidStop() {}
    
}



protocol QRScannerViewDelegate: class {
    func qrScanningDidFail()
    func qrScanningSucceededWithCode(_ str: String?)
    func qrScanningDidStop()
}

class QRScannerView: UIView {
    
    weak var delegate: QRScannerViewDelegate?
    
    /// capture settion which allows us to start and stop scanning.
    var captureSession: AVCaptureSession?
    
    // Init methods..
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        doInitialSetup()
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        doInitialSetup()
    }
    
    //MARK: overriding the layerClass to return `AVCaptureVideoPreviewLayer`.
    override class var layerClass: AnyClass  {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override var layer: AVCaptureVideoPreviewLayer {
        return super.layer as! AVCaptureVideoPreviewLayer
    }
}

extension QRScannerView {
    
    var isRunning: Bool {
        return captureSession?.isRunning ?? false
    }
    
    func startScanning() {
       captureSession?.startRunning()
    }
    
    func stopScanning() {
        captureSession?.stopRunning()
        delegate?.qrScanningDidStop()
    }
    
    /// Does the initial setup for captureSession
    private func doInitialSetup() {
        clipsToBounds = true
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch let error {
            print(error)
            return
        }
        
        if (captureSession?.canAddInput(videoInput) ?? false) {
            captureSession?.addInput(videoInput)
        } else {
            scanningDidFail()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession?.canAddOutput(metadataOutput) ?? false) {
            captureSession?.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417]
        } else {
            scanningDidFail()
            return
        }
        
        self.layer.session = captureSession
        self.layer.videoGravity = .resizeAspectFill
        
        captureSession?.startRunning()
    }
    
    func scanningDidFail() {
        delegate?.qrScanningDidFail()
        captureSession = nil
    }
    
    func found(code: String) {
        delegate?.qrScanningSucceededWithCode(code)
    }
    
}

extension QRScannerView: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        stopScanning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
    }
    
}
