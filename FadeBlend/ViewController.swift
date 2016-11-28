//
//  ViewController.swift
//  FadeBlend
//
//  Created by Oscar Perez on 11/24/16.
//  Copyright © 2016 Oscar Perez. All rights reserved.
//

import UIKit
import CoreGraphics

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    let imagePicker = UIImagePickerController()
    @IBOutlet var imageView1: UIImageView!
    @IBOutlet var imageView2: UIImageView!
    @IBOutlet var imageBlendView: UIImageView!
    @IBOutlet var takeImage1: UIButton!
    @IBOutlet var takeImage2: UIButton!
    @IBOutlet var blendSlider: UISlider!
    @IBOutlet var windowSizeSlider: UISlider!
    
    var image1: UIImage = UIImage(named: "camera-retro.png")!
    var image2: UIImage = UIImage(named: "camera-retro.png")!
    
    var targetImage: UIImage?
    var targetImageView: UIImageView?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        imageView1.image = UIImage(named: "camera-retro.png")
        imageView2.image = UIImage(named: "camera-retro.png")
        imageBlendView.image = UIImage(named: "camera-retro.png")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("Image picker canceled.")
        targetImageView = nil
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        print("Image picked.")
        
        let capturedImage = (info[UIImagePickerControllerOriginalImage] as! UIImage)

        // Create copy of captured image, otherwise it won't be stored correctly
        let origSize = CGSize(width: capturedImage.size.width, height: capturedImage.size.height)
        UIGraphicsBeginImageContext(origSize)
        capturedImage.draw(in: CGRect(x: 0, y: 0, width: origSize.width, height: origSize.height))
        
        if targetImage == image1 {
            image1 = UIGraphicsGetImageFromCurrentImageContext()!
        }
        else if targetImage == image2 {
            image2 = UIGraphicsGetImageFromCurrentImageContext()!
        }

        targetImage = nil
        UIGraphicsEndImageContext()
        

        let newSize = CGSize(width: capturedImage.size.width/4, height: capturedImage.size.height/4)
        UIGraphicsBeginImageContext(newSize)
        capturedImage.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))

        if targetImageView != nil {
            targetImageView?.image = UIGraphicsGetImageFromCurrentImageContext()
            targetImageView = nil
        }
        
        UIGraphicsEndImageContext()
        
        picker.dismiss(animated: true, completion: nil)
        
        updateBlend()
    }

    @IBAction func presentImagePicker(sender: AnyObject) {
        if UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.rear) {
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera
            
            let objSender = sender as! NSObject
            if objSender == takeImage1 {
                targetImage = image1
                targetImageView = imageView1
            }
            else if objSender == takeImage2 {
                targetImage = image2
                targetImageView = imageView2
            }
            else {
                targetImage = nil
                targetImageView = nil
            }
            
            present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func mask8bit(val:UInt32) -> UInt8 {
        return UInt8(val & 0xFF)
    }
    
    func r(val:UInt32) -> UInt8 {
        return mask8bit(val: val)
    }
    
    func g(val:UInt32) -> UInt8 {
        return mask8bit(val: val >> 8)
    }
    
    func b(val:UInt32) -> UInt8 {
        return mask8bit(val: val >> 16)
    }
    
    func a(val:UInt32) -> UInt8 {
        return mask8bit(val: val >> 24)
    }
    
    func compose(r: UInt8, g: UInt8, b:UInt8, a:UInt8) -> UInt32 {
        return UInt32(r) | UInt32(g) << 8 | UInt32(b) << 16 | UInt32(a) << 24
    }
    
    @IBAction func onWindowSizeSliderChange(sender: UISlider) {
        print("Window size slider changed: \(sender.value)")
        updateBlend()
    }
    
    @IBAction func onBlendSliderChange(sender: UISlider) {
        print("Blender slider changed: \(sender.value)")
        updateBlend()
    }
    
    @IBAction func saveImage(sender: AnyObject) {
        let alert = UIAlertController(title: "Saving", message: "Saving image...", preferredStyle: UIAlertControllerStyle.alert)
        self.present(alert, animated: true, completion: nil)
        alert.show(self, sender: self)
        
        DispatchQueue.global().async {
            guard let blendImage = self.blendImages(image1: self.image1, image2: self.image2) else {
                print("Error blending images.")
                return
            }
            
            UIImageWriteToSavedPhotosAlbum(blendImage, nil, nil, nil)

            DispatchQueue.main.async {
                alert.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func updateBlend() {
        guard let image1 = imageView1.image, let image2 = imageView2.image else {
            print("Error getting UIImage.")
            return
        }

        
        guard let blendImage = blendImages(image1: image1, image2: image2) else {
            print("Error blending images.")
            return
        }

        imageBlendView.image = blendImage
    }
    
    func blendImages(image1:UIImage, image2:UIImage) -> UIImage? {
        let windowSize = Int(windowSizeSlider.value)
        let blendRatio = blendSlider.value

        guard let cgImage1 = image1.cgImage, let cgImage2 = image2.cgImage else {
            print("Error getting CGImage.")
            return nil
        }
        
        print("image 1 orientation: \(image1.imageOrientation.rawValue) ui: \(image1.size.width), \(image1.size.height)")
        print("image 1 cg: \(cgImage1.width), \(cgImage1.height)")
        print("image 2 orientation: \(image2.imageOrientation.rawValue) ui: \(image2.size.width), \(image2.size.height)")
        print("image 2 cg: \(cgImage2.width), \(cgImage2.height)")
        
        let targetSize = CGSize(width: max(image1.size.width, image2.size.width), height: max(image1.size.height, image2.size.height))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.init(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let image1BitmapContext = CGContext.init(data: nil, width: Int(targetSize.width), height: Int(targetSize.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            print("Error creating image1 bitmap context.")
            return nil
        }
        
        guard let image2BitmapContext = CGContext.init(data: nil, width: Int(targetSize.width), height: Int(targetSize.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            print("Error creating image2 bitmap context.")
            return nil
        }
        
        guard let bitmapContext = CGContext.init(data: nil, width: Int(targetSize.width), height: Int(targetSize.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            print("Error creating bitmap context.")
            return nil
        }
        
        bitmapContext.interpolationQuality = CGInterpolationQuality.high
        
        let targetRect = CGRect(x: 0.0, y: 0.0, width: targetSize.width, height: targetSize.height)
        image1BitmapContext.draw(cgImage1, in: targetRect)
        image2BitmapContext.draw(cgImage2, in: targetRect)
        
        let i1data = image1BitmapContext.data!
        let i2data = image2BitmapContext.data!
        let destData = bitmapContext.data!
        let targetWidth = Int((Float(image2BitmapContext.width) * blendRatio)) - (windowSize/2)
        
        
        var n = 0
        let rows = Int(targetSize.height)
        // Need to use this instead of image width for proper stride alignment
        // System aligns image width in memory to be multiple of 64 bytes.
        let cols = max(cgImage1.bytesPerRow, cgImage2.bytesPerRow)/4;

        for _ in 0 ..< rows {
            for j in 0 ..< cols {
                let image1Pixel = i1data.load(fromByteOffset: n, as: UInt32.self)
                let image2Pixel = i2data.load(fromByteOffset: n, as: UInt32.self)
                
                let withinWindow = j - targetWidth
                
                if withinWindow <= 0 {
                    // Place image 1
                    destData.storeBytes(of: image1Pixel, toByteOffset: n, as: UInt32.self)
                }
                else if withinWindow < windowSize {
                    var blendPixel: UInt32
                    let image2Ratio = Float(withinWindow)/Float(windowSize)
                    let image1Ratio = (1.0 - image2Ratio)
                    
                    // Blend images
                    // R
                    let i1R = UInt8(Float(r(val: image1Pixel)) * image1Ratio)
                    let i2R = UInt8(Float(r(val: image2Pixel)) * image2Ratio)
                    
                    // G
                    let i1G = UInt8(Float(g(val: image1Pixel)) * image1Ratio)
                    let i2G = UInt8(Float(g(val: image2Pixel)) * image2Ratio)
                    
                    // B
                    let i1B = UInt8(Float(b(val: image1Pixel)) * image1Ratio)
                    let i2B = UInt8(Float(b(val: image2Pixel)) * image2Ratio)
                    
                    blendPixel = compose(r: i1R + i2R, g: i1G + i2G, b: i1B + i2B, a: 255)
                    destData.storeBytes(of: blendPixel, toByteOffset: n, as: UInt32.self)
                }
                else {
                    // Place image 2
                    destData.storeBytes(of: image2Pixel, toByteOffset: n, as: UInt32.self)
                }
                
                n += 4
            }
        }
        
        return UIImage(cgImage: bitmapContext.makeImage()!)
    }
}

