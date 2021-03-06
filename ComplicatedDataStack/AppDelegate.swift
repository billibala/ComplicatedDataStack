//
//  AppDelegate.swift
//  ComplicatedDataStack
//
//  Created by Bill on 11/21/20.
//

import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "ComplicatedDataStack")

        guard let storeConfig = container.persistentStoreDescriptions.first else {
            fatalError()
        }

        storeConfig.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
//        storeConfig.configuration = "EventContent"
//        storeConfig.configuration = "Default"
        /**
         Questions:
         * Will get receive this notification on local change? (changes made by the same process)
         * Which thread does the notification handler get invokved?
         */
        storeConfig.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Add another store
//        let userDataConfiguration = NSPersistentStoreDescription(url: storeConfig.url!.deletingLastPathComponent().appendingPathComponent("UserContent.sqlite"))

//        container.persistentStoreDescriptions = [storeConfig, userDataConfiguration]
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print(storeDescription.url!.absoluteString)
            container.viewContext.perform {
                /**
                 Automatically merges changes is great if your app has a small data set.

                 In our case, hundreds of events and thousands of participants are not rare scenario.

                 Automatically merges changes process all changes regardless.

                 On bulk insert, we don't want to merge any change. Since the entire data set has changed, there's no point to look into each change and merge every change into the view context. We just need to refresh or reset the entire view context to reload a fresh set of data.
                 */
                container.viewContext.automaticallyMergesChangesFromParent = false
                try! container.viewContext.setQueryGenerationFrom(.current)
                // To trigger pinning
                container.viewContext.refreshAllObjects()
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

