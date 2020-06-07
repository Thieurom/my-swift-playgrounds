import Combine

extension Subscribers {
    /// A simple subscriber that requests an unlimited number of values upon subscription.
    final class MySink<Input, Failure>: Subscriber, Cancellable where Failure : Error {
        private let receiveCompletion: (Subscribers.Completion<Failure>) -> Void
        private let receiveValue: (Input) -> Void
        private var subscription: Subscription?
        
        init(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
             receiveValue: @escaping (Input) -> Void) {
            self.receiveValue = receiveValue
            self.receiveCompletion = receiveCompletion
        }
        
        func receive(subscription: Subscription) {
            self.subscription = subscription
            subscription.request(.unlimited)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            receiveValue(input)
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            receiveCompletion(completion)
            subscription = nil
        }
        
        func cancel() {
            subscription?.cancel()
            subscription = nil
        }
    }
}

extension Publisher {
    func mySink(receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void),
                receiveValue: @escaping ((Output) -> Void)) -> AnyCancellable {
        let mySink = Subscribers.MySink(receiveCompletion: receiveCompletion,
                                        receiveValue: receiveValue)
        
        subscribe(mySink)
        return AnyCancellable(mySink)
    }
}

// Tests
var subscriptions = Set<AnyCancellable>()

// 1
let publisher = [1, 2, 3, 4].publisher
publisher
    .mySink(receiveCompletion: { print("Received completion: \($0)") },
            receiveValue: { print("Received value: \($0)") })
    .store(in: &subscriptions)

// 2
enum MyError: Error {
    case someError
}

let subject = PassthroughSubject<String, MyError>()
let mySink2 = subject
    .mySink(receiveCompletion: { print("Received completion: \($0)") },
            receiveValue: { print("Received value: \($0)") })

mySink2.store(in: &subscriptions)

subject.send("A")
subject.send("B")
subject.send(completion: .failure(.someError))

//mySink2.cancel()
subject.send("C")

subject.send(completion: .finished)
