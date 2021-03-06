# HMRequestFramework-Swift

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![CocoaPods](https://img.shields.io/cocoapods/v/HMRequestFramework.svg)
[![Build Status](https://travis-ci.org/protoman92/HMRequestFramework-Swift.svg?branch=master)](https://travis-ci.org/protoman92/HMRequestFramework-Swift)
[![Coverage Status](https://coveralls.io/repos/github/protoman92/HMRequestFramework-Swift/badge.svg?branch=master)](https://coveralls.io/github/protoman92/HMRequestFramework-Swift?branch=master)

Network/Database request framework for iOS clients.

This framework provides handlers, processors and middlewares to manage all manners of requests, be it database or network. It guarantees immutability in most cases and relies heavily on **RxSwift**.

## General architecture

The master architecture at play is a modified railway, in the sense that the result of the previous action becomes a parameter for the next one. For e,g,, we have 2 requests that need to be executed sequentially - one fetches data from a remote server and the other saves that data to a local DB. Each request is comprised of a **Previous** result, a **Request Generator** and a **Result Processor**, such that:

- The previous result is wrapped in a **Try** data structure which contains either an Error or a Success value. If the former request succeeds, it passes down a **Success Try**, and a **Failure Try** otherwise. Errors are caught automatically in order to prevent them being thrown.

- The request generator, found in **HMRequestGenerator.swift**, takes the previous result to generate a request object. If Prev is a failure, the generator is responsible for determining which errors are recoverable, and it may still generate a request regardless (albeit with some backup parameters) - otherwise, it will propagate the failure downstream until it reaches a generator that considers it recoverable, or is consumed by a subscriber. Its signature is:

```swift
(Try<Prev>) throws -> Observable<Req>
```

- The result processor, found in **HMResultProcessor.swift**, takes the base result of a request and transform it to something else that can be used easily by the upper layers. For e.g., a network request returns an Observable<Data>, and a CoreData request may return NSManagedObject. In both cases, we do not want to leak the implementation of the underlying managers. Its signature is:

```swift
(Try<Val1>) throws -> Observable<Try<Val2>>
```

With this architecture, there is only 1 positive flow for any stream. Since errors are not thrown, we can be sure the stream will stay alive at all times.

We can also add middlewares to intercept requests and transform them into a clone with additional parameters. This is especially useful if we want to set a common retry count or add headers automatically. Each request object can also declare an Array of middleware filters to weed out middlewares it does not want. Middlewares should be added to a middleware manager (which will be added to the request processors during the build phase).

For data structures, we make abundant use of the Buildable pattern (based on Builders):

- A **Buildable** is something that can be built. It conforms to **BuildableType**. Each Buildable has one Builder.

- A **Builder** is something that can build. It conforms to **BuilderType**. Each Builder has one Buildable.

When Buildable.Builder == Builder.Buildable, we can use a method called **cloneBuilder()** to expose a Builder whose Buildable has all the properties of the previous Buildable, upon which we can mutate its properties with the Builder's setter methods. This allows us to enforce immutability on our Buildable objects, since there is no way to mutate them aside from cloning and mutating on the clone itself. For a better understanding of this pattern, please read the documentation found in **HMBuildableType.swift**.

## Immutable CoreData

The crux of this library is the **HMCDManager**, found in **HMCDManager.swift**, a manager that handles CoreData-related work. It is written in a way that enforces immutability and maximizes statelessness, even under overwhelming resistance from NSManagedObjectContext and NSManagedObject - both of which are heavily dependent on shared state. It does so using a variety of protocols that hide away all things that are coupled to CoreData.

To make good use of HMCDManager, we employ the parallel object model:

- In our universe, **NSManagedObject** is second class citizen. Its sole purpose is to pass on its properties and be disposed of immediately.

- Instead of NSManagedObject, we only expose **Pure Object** to the upper layers. These pure objects carry the same properties as their CoreData counterparts, but they know nothing of NSManagedObjectContext.

There are a few protocols that we need to look at to get a better understanding of this model:

- **HMCDObjectType**: All NSManagedObject subtypes conform to this protocol. Its primary purpose is to provide the entityName for a fetch request.

- **HMCDPureObjectType**: All pure objects conform to this protocol. It has an associatedType CDClass that conforms to HMCDObjectType, so that each pure object type is tied to one CoreData object type.

- **HMCDPureObjectConvertibleType**: All NSManagedObject subtypes conform to this protocol. It has an associatedType PureObject that conforms to HMCDPureObjectType, and allows a CoreData object to convert into its pure object implementation. When Convertible.PureObject.CDClass == Convertible, the **asPureObject()** method is implemented automatically.

There are also various Buildable/Builder protocols specific to CoreData in use, but we shall not go into them here. They can all be found in **database/coredata/protocol**.

The HMCDManager has various extensions that deal with these protocols to fetch/save/delete/upsert data. Please consult files whose names are in the form **HMCDManager+X.swift**. Also check out the tests and sample app (**HMRequestManager-Demo**) for a demonstration of the techniques being used.

