import UIKit
import Social
import MobileCoreServices
import Photos

/// 共有されるメディアのデータを定義する構造体
struct SharedMediaFile: Codable {
    let path: String
    let mimeType: String?
    let thumbnail: String?
    let duration: Double?
    let message: String?
    let type: SharedMediaType
    
    // JSONのエンコード/デコードの一貫性を保つために明示的にCodingKeysを定義
    enum CodingKeys: String, CodingKey {
        case path
        case mimeType
        case thumbnail
        case duration
        case message
        case type
    }
}

// 
/// 共有されるメディアの種類を定義する列挙型
/// - image: 画像ファイル
/// - video: 動画ファイル
/// - text: テキストデータ
/// - file: 一般的なファイル
/// - url: URLリンク
enum SharedMediaType: String, Codable {
    case image
    case video
    case text
    case file
    case url
}

class ShareViewController: SLComposeServiceViewController {
    var hostAppBundleIdentifier = ""
    var appGroupId = ""
    let sharedKey = "ShareKey"
    var sharedMedia: [SharedMediaFile] = []
    var sharedText: [String] = []
    let imageContentType = kUTTypeImage as String
    let videoContentType = kUTTypeMovie as String
    let textContentType = kUTTypeText as String
    let urlContentType = kUTTypeURL as String
    let fileURLType = kUTTypeFileURL as String

    private func loadIds() {
        // アプリグループIDを直接指定
        appGroupId = "group.com.example.receiveSharingFiles"
        
        // ホストアプリのバンドルIDを直接指定
        hostAppBundleIdentifier = "com.example.receiveSharingFiles"
    }

    /// ビューがロードされたときに呼ばれるメソッド
    override func viewDidLoad() {
        super.viewDidLoad()
        loadIds()
        
        // デバッグ用
        print("ShareViewController viewDidLoad")
    }

    /// ビューが表示されたときに呼ばれるメソッド
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // デバッグ用
        print("ShareViewController viewDidAppear")
    }

    /// 共有ボタンが押されたときに呼ばれるメソッド
    override func didSelectPost() {
        print("didSelectPost started")
        
        if let content = extensionContext?.inputItems[0] as? NSExtensionItem,
        let attachments = content.attachments {
            let total = attachments.count
            print("Processing \(total) attachments")
            
            for (index, attachment) in attachments.enumerated() {
                print("Processing attachment \(index + 1) of \(total)")
                
                // ファイルのUTIタイプを判定
                let types = [kUTTypeFileURL as String]
                let availableType = types.first { attachment.hasItemConformingToTypeIdentifier($0) }
                
                if let type = availableType {
                    print("Found supported type: \(type)")
                    handleFiles(content: content, attachment: attachment, index: index)
                } else {
                    print("No supported type found")
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            }
        } else {
            print("No valid content found")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    /// キャンセルボタンが押されたときに呼ばれるメソッド
    override func didSelectCancel() {
        print("didSelectCancel called")
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    /// コンテンツが有効かどうかを返すメソッド
    override func isContentValid() -> Bool {
        print("isContentValid called")
        return true
    }

    /// 設定項目を返すメソッド
    override func configurationItems() -> [Any]! {
        print("configurationItems called")
        return []
    }

    /// テキストデータを処理するメソッド
    private func handleText(content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: textContentType, options: nil) { [weak self] data, error in
            guard let strongSelf = self else { return }

            if error == nil, let item = data as? String {
                strongSelf.sharedText.append(item)

                if index == (content.attachments?.count ?? 0) - 1 {
                    print("Processing last item")
                    let encodedData = try? JSONEncoder().encode(strongSelf.sharedMedia)
                    if let encodedData = encodedData {
                        print("Encoded data: \(String(data: encodedData, encoding: .utf8) ?? "invalid data")")
                        let userDefaults = UserDefaults(suiteName: strongSelf.appGroupId)
                        userDefaults?.set(encodedData, forKey: strongSelf.sharedKey)
                        let success = userDefaults?.synchronize() ?? false
                        print("Data saved to UserDefaults: \(success)")
                        strongSelf.redirectToHostApp(type: .file)
                    } else {
                        print("Failed to encode shared media")
                        strongSelf.dismissWithError()
                    }
                }
            } else {
                strongSelf.dismissWithError()
            }
        }
    }

    /// URLデータを処理するメソッド
    private func handleUrl(content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: urlContentType, options: nil) { [weak self] data, error in

            if error == nil, let item = data as? URL, let this = self {

                this.sharedText.append(item.absoluteString)

                // If this is the last item, save imagesData in userDefaults and redirect to the host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: this.appGroupId)
                    userDefaults?.set(this.sharedText, forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .text)
                }

            } else {
                self?.dismissWithError()
            }
        }
    }

    /// 画像データを処理するメソッド
    private func handleImages(content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: imageContentType, options: nil) { [weak self] data, error in

            if error == nil, let url = data as? URL, let this = self {

                // Always copy
                let fileName = this.getFileName(from: url, type: .image)
                let newPath = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: this.appGroupId)!
                    .appendingPathComponent(fileName)
                let copied = this.copyFile(at: url, to: newPath)
                if copied {
                    this.sharedMedia.append(SharedMediaFile(
                        path: newPath.absoluteString,
                        mimeType: "image/\(url.pathExtension.lowercased())",
                        thumbnail: nil,
                        duration: nil,
                        message: nil,
                        type: .image
                    ))
                }

                // If this is the last item, save imagesData in userDefaults and redirect to the host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: this.appGroupId)
                    userDefaults?.set(this.toData(data: this.sharedMedia), forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .media)
                }

            } else {
                self?.dismissWithError()
            }
        }
    }

    /// 動画データを処理するメソッド
    private func handleVideos(content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        attachment.loadItem(forTypeIdentifier: videoContentType, options: nil) { [weak self] data, error in

            if error == nil, let url = data as? URL, let this = self {

                // Always copy
                let fileName = this.getFileName(from: url, type: .video)
                let newPath = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: this.appGroupId)!
                    .appendingPathComponent(fileName)
                let copied = this.copyFile(at: url, to: newPath)
                if copied {
                    guard let sharedFile = this.getSharedMediaFile(forVideo: newPath) else {
                        return
                    }
                    let videoFile = SharedMediaFile(
                        path: sharedFile.path,
                        mimeType: "video/\(url.pathExtension.lowercased())",
                        thumbnail: sharedFile.thumbnail,
                        duration: sharedFile.duration,
                        message: nil,
                        type: .video
                    )
                    this.sharedMedia.append(videoFile)
                }

                // If this is the last item, save imagesData in userDefaults and redirect to the host app
                if index == (content.attachments?.count)! - 1 {
                    let userDefaults = UserDefaults(suiteName: this.appGroupId)
                    userDefaults?.set(this.toData(data: this.sharedMedia), forKey: this.sharedKey)
                    userDefaults?.synchronize()
                    this.redirectToHostApp(type: .media)
                }

            } else {
                self?.dismissWithError()
            }
        }
    }

    /// ファイルデータを処理するメソッド
    private func handleFiles(content: NSExtensionItem, attachment: NSItemProvider, index: Int) {
        print("Starting file handling for index: \(index)")
        
        attachment.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { [weak self] data, error in
            guard let strongSelf = self else {
                print("Self is nil")
                return
            }
            
            if let error = error {
                print("File handling error: \(error.localizedDescription)")
                strongSelf.dismissWithError()
                return
            }
            
            guard let url = data as? URL else {
                print("Invalid data received")
                strongSelf.dismissWithError()
                return
            }
            
            print("Processing file at URL: \(url)")
            
            let fileName = strongSelf.getFileName(from: url, type: .file)
            print("Generated filename: \(fileName)")
            
            guard let containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: strongSelf.appGroupId) else {
                    print("Failed to get container URL")
                    strongSelf.dismissWithError()
                    return
            }
            
            let newPath = containerURL.appendingPathComponent(fileName)
            print("Target path: \(newPath.path)")
            
            do {
                if FileManager.default.fileExists(atPath: newPath.path) {
                    try FileManager.default.removeItem(at: newPath)
                    print("Removed existing file")
                }
                
                try FileManager.default.copyItem(at: url, to: newPath)
                print("File copied successfully")
                
                let sharedFile = SharedMediaFile(
                    path: newPath.path,
                    mimeType: url.mimeType(),
                    thumbnail: nil,
                    duration: nil,
                    message: nil,
                    type: .file
                )

                var currentSharedMedia = strongSelf.sharedMedia
                currentSharedMedia.append(sharedFile)
                strongSelf.sharedMedia = currentSharedMedia
                
                if index == (content.attachments?.count ?? 0) - 1 {
                    print("Processing last item")
                    do {
                        let encodedData = try JSONEncoder().encode(strongSelf.sharedMedia)
                        print("Encoded data: \(String(data: encodedData, encoding: .utf8) ?? "invalid data")")
                        let userDefaults = UserDefaults(suiteName: strongSelf.appGroupId)
                        userDefaults?.set(encodedData, forKey: strongSelf.sharedKey)
                        let success = userDefaults?.synchronize() ?? false
                        print("Data saved to UserDefaults: \(success)")
                        strongSelf.redirectToHostApp(type: .file)
                    } catch {
                        print("Failed to encode shared media: \(error)")
                        strongSelf.dismissWithError()
                    }
                }
            } catch {
                print("File operation error: \(error)")
                strongSelf.dismissWithError()
            }
        }
    }

    /// エラーを表示するメソッド
    private func dismissWithError(message: String = "ファイルの共有中にエラーが発生しました。再度お試しください。") {
        print("Error occurred: \(message)")
        let alert = UIAlertController(
            title: "エラー",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "OK",
            style: .default,
            handler: { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        ))
        
        present(alert, animated: true)
    }

    /// ホストアプリにリダイレクトするメソッド
    private func redirectToHostApp(type: RedirectType) {
        print("Redirecting to host app with type: \(type)")
        loadIds()
        
        let urlScheme = "ShareMedia-\(hostAppBundleIdentifier)"
        let urlString = "\(urlScheme)://dataUrl=\(sharedKey)#\(type)"
        
        guard let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: encodedUrlString) else {
            print("Failed to create URL from: \(urlString)")
            dismissWithError(message: "アプリを開くためのURLの作成に失敗しました")
            return
        }
        
        var responder = self as UIResponder?
        while responder != nil {
            if let application = responder as? UIApplication {
                print("Found UIApplication responder")
                application.open(url, options: [:]) { [weak self] success in
                    print("URL open result: \(success)")
                    if success {
                        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    } else {
                        self?.dismissWithError(message: "アプリを開けませんでした")
                    }
                }
                return
            }
            responder = responder?.next
        }
        
        print("No UIApplication responder found")
        dismissWithError(message: "アプリを開くことができませんでした")
    }

    /// リダイレクトの種類を定義する列挙型
    enum RedirectType: String, Codable {
        case media
        case text
        case file
    }

    /// ファイルの拡張子を取得するメソッド
    func getExtension(from url: URL, type: SharedMediaType) -> String {
        let parts = url.lastPathComponent.components(separatedBy: ".")
        var ex: String? = nil
        if (parts.count > 1) {
            ex = parts.last
        }

        if (ex == nil) {
            switch type {
            case .image:
                ex = "PNG"
            case .video:
                ex = "MP4"
            case .file:
                ex = "TXT"
            case .text:
                ex = "TXT"
            case .url:
                ex = "URL"
            }
        }
        return ex ?? "Unknown"
    }

    /// ファイル名を取得するメソッド
    func getFileName(from url: URL, type: SharedMediaType) -> String {
        var name = url.lastPathComponent

        if (name.isEmpty) {
            name = UUID().uuidString + "." + getExtension(from: url, type: type)
        }

        return name
    }

    /// ファイルをコピーするメソッド
    func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) {
                try FileManager.default.removeItem(at: dstURL)
            }
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch (let error) {
            print("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
            return false
        }
        return true
    }

    /// 動画ファイルから共有メディアファイルを取得するメソッド
    private func getSharedMediaFile(forVideo: URL) -> SharedMediaFile? {
        let asset = AVAsset(url: forVideo)
        let duration = (CMTimeGetSeconds(asset.duration) * 1000).rounded()
        let thumbnailPath = getThumbnailPath(for: forVideo)

        if FileManager.default.fileExists(atPath: thumbnailPath.path) {
            return SharedMediaFile(path: forVideo.absoluteString, mimeType: nil, thumbnail: thumbnailPath.absoluteString, duration: duration, message: nil, type: .video)
        }

        var saved = false
        let assetImgGenerate = AVAssetImageGenerator(asset: asset)
        assetImgGenerate.appliesPreferredTrackTransform = true
        assetImgGenerate.maximumSize =  CGSize(width: 360, height: 360)
        do {
            let img = try assetImgGenerate.copyCGImage(at: CMTimeMakeWithSeconds(600, preferredTimescale: Int32(1.0)), actualTime: nil)
            try UIImage.pngData(UIImage(cgImage: img))()?.write(to: thumbnailPath)
            saved = true
        } catch {
            saved = false
        }

        return saved ? SharedMediaFile(path: forVideo.absoluteString, mimeType: nil, thumbnail: thumbnailPath.absoluteString, duration: duration, message: nil, type: .video) : nil
    }

    /// サムネイルのパスを取得するメソッド
    private func getThumbnailPath(for url: URL) -> URL {
        let fileName = Data(url.lastPathComponent.utf8).base64EncodedString().replacingOccurrences(of: "==", with: "")
        let path = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId)!
            .appendingPathComponent("\(fileName).jpg")
        return path
    }

    /// 共有メディアデータをDataに変換するメソッド
    func toData(data: [SharedMediaFile]) -> Data {
        let encodedData = try? JSONEncoder().encode(data)
        return encodedData ?? Data()
    }
}

/// 配列のセーフインデックスアクセスを提供する拡張
extension Array {
    subscript (safe index: UInt) -> Element? {
        return Int(index) < count ? self[Int(index)] : nil
    }
}

/// URLのMIMEタイプを取得する拡張
extension URL {
    func mimeType() -> String {
        let pathExtension = self.pathExtension
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
}
