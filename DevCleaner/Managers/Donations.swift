import StoreKit

// MARK: Donations product fetch error
public enum DonationsProductsFetchError {
    case noProductsAvailable,
         invalidProducts([String]),
         storeError(Error)
}

// MARK: - Donations delegate
public protocol DonationsDelegate: AnyObject {
    func donations(_ donations: Donations, donationProductsFetchFailedWithError error: DonationsProductsFetchError)
    func donations(_ donations: Donations, didReceive products: [DonationProduct])
    
    func transactionDidStart(for product: DonationProduct)
    func transactionIsBeingProcessed(for product: DonationProduct)
    func transactionDidFinish(for product: DonationProduct, error: Error?)
}

// MARK: - Donation product
public struct DonationProduct {
    public enum Kind: String {
        case smallCoffee = "SMALL_COFFEE",
             bigCoffee = "BIG_COFFEE",
             lunch = "LUNCH"
        
        public static var allKinds: [Kind] {
            [.smallCoffee, .bigCoffee, .lunch]
        }
    }
    
    public let kind: Kind
    public let skProduct: SKProduct
    
    public let price: String
    public let info: String
    
    public var identifier: String {
        kind.rawValue
    }
    
    public init?(product: SKProduct) {
        guard let kind = Kind(rawValue: product.productIdentifier) else {
            return nil
        }
        
        self.kind = kind
        skProduct = product
        
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = product.priceLocale
        
        price = nf.string(from: skProduct.price) ?? ""
        info = skProduct.localizedTitle
    }
}

// MARK: - Donations Manager
public final class Donations: NSObject {
    // MARK: Properties
    private var productsRequest: SKProductsRequest? = nil
    private var iapProducts: [DonationProduct] = []
    
    public weak var delegate: DonationsDelegate? = nil
    
    public var canMakeDonations: Bool {
#if DEBUG
        return SKPaymentQueue.canMakePayments()
#else
        // we can make payments and we're on Mac App Store build
        let canMakePayments = SKPaymentQueue.canMakePayments()
        let receiptPresent: Bool
        if let receiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: receiptURL.path) {
            receiptPresent = true
        } else {
            receiptPresent = false
        }
        
        return canMakePayments && receiptPresent
        
#endif
    }
    
    public static let shared = Donations()
    
    // MARK: Initialization
    private override init() {
        super.init()
    }
    
    // MARK: Transaction observation
    public func startObservingTransactionsQueue() {
        SKPaymentQueue.default().add(self)
    }
    
    // MARK: Purchasing donations
    public func fetchProductsInfo() {
        let donationProductsIds = DonationProduct.Kind.allKinds.map { $0.rawValue }
        
        productsRequest = SKProductsRequest(productIdentifiers: Set(donationProductsIds))
        productsRequest?.delegate = self
        productsRequest?.start()
        
        log.info("Requesting donation products with ids: \(donationProductsIds)")
    }
    
    public func buy(product: DonationProduct) {
        log.info("Purchasing donation product: \(product.kind.rawValue) - \(product.identifier)")
        
        let payment = SKMutablePayment(product: product.skProduct)
        payment.quantity = 1
        
        SKPaymentQueue.default().add(payment)
        
        delegate?.transactionDidStart(for: product)
    }
}

extension Donations: SKProductsRequestDelegate {
    public func requestDidFinish(_ request: SKRequest) {
        log.info("Products request finished successfully")
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        log.error("SKProductsRequest failed: \(error)")
        delegate?.donations(self, donationProductsFetchFailedWithError: .storeError(error))
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let expectedNumberOfProducts = DonationProduct.Kind.allKinds.count
        
        guard !response.products.isEmpty else {
            log.error("No products returned from store!")
            
            delegate?.donations(self, donationProductsFetchFailedWithError: .noProductsAvailable)
            return
        }
        
        guard response.products.count == expectedNumberOfProducts else {
            log.error("Unexpected number of products returned from store: \(response.products.count)")
            
            delegate?.donations(self, donationProductsFetchFailedWithError: .invalidProducts(response.products.map { $0.productIdentifier } ))
            return
        }
        
        let donationProducts = response.products.compactMap { DonationProduct(product: $0) }
        
        guard donationProducts.count == expectedNumberOfProducts else {
            log.error("Not all products have proper ids: \(response.products.count)")
            
            delegate?.donations(self, donationProductsFetchFailedWithError: .invalidProducts(response.products.map { $0.productIdentifier } ))
            return
        }
        
        iapProducts = donationProducts
        
        delegate?.donations(self, didReceive: iapProducts)
    }
}

extension Donations: SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            // get our product related to transaction
            guard let transactionProduct = iapProducts.filter( { $0.identifier == transaction.payment.productIdentifier } ).first else {
                log.warning("Donations: Updated transaction thats product have unknown identifier or not yet fetched: \(transaction.payment.productIdentifier)")
                
                // we can safely finish such transaction since we don't deliver any special stuff
                queue.finishTransaction(transaction)
                
                continue
            }
            
            switch transaction.transactionState {
            case .purchasing, .deferred:
                delegate?.transactionIsBeingProcessed(for: transactionProduct)
                
            case .purchased, .failed:
                delegate?.transactionDidFinish(for: transactionProduct, error: transaction.error)
                queue.finishTransaction(transaction)
                
            case .restored:
                // we don't support restored purchases here, so no delegate
                queue.finishTransaction(transaction)
                
            @unknown default:
                // in case of any future cases, just finish transaction which seems sensible
                queue.finishTransaction(transaction)
            }
        }
    }
}
