//
//  Persistence.swift
//  HelsinkiBikeBuddy
//
//  Created by Juan Covarrubias on 6.2.2021.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController(inMemory: false)
    static let testing = PersistenceController(inMemory: true)

    let container: NSPersistentContainer

    init(inMemory: Bool) {
        container = NSCustomPersistentContainer(name: "HelsinkiBikeBuddy")
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        }
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }
}


class NSCustomPersistentContainer: NSPersistentContainer {

    override open class func defaultDirectoryURL() -> URL {
        var storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.HelsinkiBikeBuddy")
        storeURL = storeURL?.appendingPathComponent("HelsinkiBikeBuddy.sqlite")
        return storeURL!
    }

}
