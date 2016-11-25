//
//  AlamofireExtension.swift
//  RealmKit
//
//  Created by Michael Loistl on 04/10/2016.
//  Copyright © 2016 Aplo. All rights reserved.
//

import Foundation
import Alamofire

public extension DataResponse {
    
    public var isSuccess: Bool {
        return (response?.statusCode ?? 0) >= 200 && (response?.statusCode ?? 0) < 300
    }
    
    public var json: Any? {
        return result.value
    }
}
