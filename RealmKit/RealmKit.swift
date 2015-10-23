//
//  RealmKit.swift
//  RealmKit
//
//  Created by Michael Loistl on 22/10/2015.
//  Copyright © 2015 Aplo. All rights reserved.
//

import Foundation

public class RealmKit {
    
    public enum SyncStatus: String {
        case Sync = "sync"
        case Syncing = "syncing"
        case Synced = "synced"
        case Failed = "failed"
    }
}