//
//  DataGroup1.swift
//
//  Created by Andy Qua on 01/02/2021.
//

import Foundation

@available(iOS 13, macOS 10.15, *)
public enum DocTypeEnum: String {
    case TD1
    case TD2
    case OTHER
    
    var desc: String {
        get {
            return self.rawValue
        }
    }
}

@available(iOS 13, macOS 10.15, *)
public class DataGroup1 : DataGroup {
    
    private enum DriverLicense: String {
        case gender = "5F02"
        case issuingMemberState = "5F03"
        case lastName = "5F04"
        case firstName = "5F05"
        case dateOfBirth = "5F06"
        case placeOfBirth = "5F07"
        case nationality = "5F08"
        case dateOfIssue = "5F0A"
        case dateOfExpiry = "5F0B"
        case issuingAuthority = "5F0C"
        case documentNumber = "5F0E"
        
        var intHex: Int {
            Int(rawValue, radix:16)!
        }
    }
    
    private enum Passport {
        static let documentType = "5F03"
        static let personalNumber = "53"
        static let personalNumberCheckDigit = "5F02"
        static let documentNumber = "5A"
        static let documentNumberCheckDigit = "5F04"
        static let issuingAuthority = "5F28"
        static let documentExpiryDate = "59"
        static let documentExpiryDateCheckDigit = "5F06"
        static let dateOfBirth = "5F57"
        static let dateOfBirthCheckDigit = "5F05"
        static let gender = "5F35"
        static let nationality = "5F2C"
        static let firstName = "5B"
        static let lastName = "5B"
        static let mrz = "5F1F"
        static let mrzLineCheckDigit = "5F07"
    }
    
    // MARK: - Document Data - Elements
    public private(set) lazy var documentType: String = {
        return isPassport ? String(elements[Passport.documentType]?.first ?? "?") : "D"
    }()
    public private(set) lazy var documentSubType: String = {
        return isPassport ? String(elements[Passport.documentType]?.last ?? "?") : "1"
    }()
    public private(set) lazy var personalNumber: String = {
        return isDrivers ? (elements[Passport.personalNumber] ?? "?").replacingOccurrences(of: "<", with: "" ) : "?"
    }()
    public private(set) lazy var documentNumber: String = {
        guard isPassport else {
            return elements[DriverLicense.documentNumber.rawValue] ?? "?"
        }
        return (elements[Passport.documentNumber] ?? "?").replacingOccurrences(of: "<", with: "")
    }()
    public private(set) lazy var issuingAuthority: String = {
        guard isPassport else {
            return elements[DriverLicense.issuingMemberState.rawValue] ?? "?"
        }
        return elements[Passport.issuingAuthority] ?? "?"
    }()
    public private(set) lazy var documentExpiryDate: String = {
        guard isPassport else {
            return elements[DriverLicense.dateOfExpiry.rawValue] ?? "?"
        }
        return elements[Passport.documentExpiryDate] ?? "?"
    }()
    public private(set) lazy var dateOfBirth: String = {
        guard isPassport else {
            return elements[DriverLicense.dateOfBirth.rawValue] ?? "?"
        }
        return elements[Passport.dateOfBirth] ?? "?"
    }()
    public private(set) lazy var dateOfIssue: String = {
        guard isDrivers else {
            return "?"
        }
        return elements[DriverLicense.dateOfIssue.rawValue] ?? "?"
    }()
    public private(set) lazy var gender: String = {
        guard isPassport else {
            return elements[DriverLicense.gender.rawValue] ?? "?"
        }
        return elements[Passport.gender] ?? "?"
    }()
    public private(set) lazy var nationality: String = {
        guard isPassport else {
            return elements[DriverLicense.nationality.rawValue] ?? "?"
        }
        return elements[Passport.nationality] ?? "?"
    }()
    
    public private(set) lazy var lastName: String = {
        guard isPassport else {
            return elements[DriverLicense.lastName.rawValue] ?? "?"
        }
        let names = (elements[Passport.lastName] ?? "?").components(separatedBy: "<<")
        return names[0].replacingOccurrences(of: "<", with: " " )
    }()
    
    public private(set) lazy var firstName: String = {
        guard isPassport else {
            return elements[DriverLicense.firstName.rawValue] ?? "?"
        }
        
        let names = (elements[Passport.firstName] ?? "?").components(separatedBy: "<<")
        var name = ""
        for i in 1 ..< names.count {
            let fn = names[i].replacingOccurrences(of: "<", with: " " ).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            name += fn + " "
        }
        return name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }()
    
    public private(set) lazy var passportMRZ: String? = { return elements[Passport.mrz] }()
    
    private var elements: [String:String] = [:]
    public private(set) var isDrivers: Bool = false
    private var isPassport: Bool { return !isDrivers }
    
    required init(_ data: [UInt8]) throws {
        try super.init(data)
        datagroupType = .DG1
    }
    
    // MARK: - Parsing
    
    override func parse(_ data: [UInt8]) throws {
        let tag = try getNextTag()
        
        if tag == 0x5F1F {
            try parseMrzElements()
        } else if tag == 0x5F01 {
            isDrivers = true
            return try parseDriversTag(for: tag)
        } else {
            throw NFCPassportReaderError.InvalidResponse
        }
    }
    
    // MARK: - Parsing Passport Elements
    
    private func parseMrzElements() throws {
        let body = try getNextValue()
        let docType = getMRZType(length:body.count)
        
        switch docType {
            case .TD1:
                self.parseTd1(body)
            case .TD2:
                self.parseTd2(body)
            default:
                self.parseOther(body)
        }
        
        // Store MRZ data
        elements[Passport.mrz] = String(bytes: body, encoding:.utf8)
    }
    
    func parseTd1(_ data : [UInt8]) {
        elements[Passport.documentType] = String(bytes: data[0..<2], encoding:.utf8)
        elements[Passport.issuingAuthority] = String( bytes:data[2..<5], encoding:.utf8)
        elements[Passport.documentNumber] = String( bytes:data[5..<14], encoding:.utf8)
        elements[Passport.documentNumberCheckDigit] = String( bytes:data[14..<15], encoding:.utf8)
        elements[Passport.personalNumber] = (String( bytes:data[15..<30], encoding:.utf8) ?? "") +
            (String( bytes:data[48..<59], encoding:.utf8) ?? "")
        elements[Passport.dateOfBirth] = String( bytes:data[30..<36], encoding:.utf8)
        elements[Passport.dateOfBirthCheckDigit] = String( bytes:data[36..<37], encoding:.utf8)
        elements[Passport.gender] = String( bytes:data[37..<38], encoding:.utf8)
        elements[Passport.documentExpiryDate] = String( bytes:data[38..<44], encoding:.utf8)
        elements[Passport.documentExpiryDateCheckDigit] = String( bytes:data[44..<45], encoding:.utf8)
        elements[Passport.nationality] = String( bytes:data[45..<48], encoding:.utf8)
        elements[Passport.mrzLineCheckDigit] = String( bytes:data[59..<60], encoding:.utf8)
        elements[Passport.firstName] = String( bytes:data[60...], encoding:.utf8)
    }
    
    func parseTd2(_ data : [UInt8]) {
        elements[Passport.documentType] = String( bytes:data[0..<2], encoding:.utf8)
        elements[Passport.issuingAuthority] = String( bytes:data[2..<5], encoding:.utf8)
        elements[Passport.firstName] = String( bytes:data[5..<36], encoding:.utf8)
        elements[Passport.documentNumber] = String( bytes:data[36..<45], encoding:.utf8)
        elements[Passport.documentNumberCheckDigit] = String( bytes:data[45..<46], encoding:.utf8)
        elements[Passport.nationality] = String( bytes:data[46..<49], encoding:.utf8)
        elements[Passport.dateOfBirth] = String( bytes:data[49..<55], encoding:.utf8)
        elements[Passport.dateOfBirthCheckDigit] = String( bytes:data[55..<56], encoding:.utf8)
        elements[Passport.gender] = String( bytes:data[56..<57], encoding:.utf8)
        elements[Passport.documentExpiryDate] = String( bytes:data[57..<63], encoding:.utf8)
        elements[Passport.documentExpiryDateCheckDigit] = String( bytes:data[63..<64], encoding:.utf8)
        elements[Passport.personalNumber] = String( bytes:data[64..<71], encoding:.utf8)
        elements[Passport.mrzLineCheckDigit] = String( bytes:data[71..<72], encoding:.utf8)
    }
    
    func parseOther(_ data : [UInt8]) {
        elements[Passport.documentType] = String( bytes:data[0..<2], encoding:.utf8)
        elements[Passport.issuingAuthority] = String( bytes:data[2..<5], encoding:.utf8)
        elements[Passport.firstName]   = String( bytes:data[5..<44], encoding:.utf8)
        elements[Passport.documentNumber]   = String( bytes:data[44..<53], encoding:.utf8)
        elements[Passport.documentNumberCheckDigit] = String( bytes:[data[53]], encoding:.utf8)
        elements[Passport.nationality] = String( bytes:data[54..<57], encoding:.utf8)
        elements[Passport.dateOfBirth] = String( bytes:data[57..<63], encoding:.utf8)
        elements[Passport.dateOfBirthCheckDigit] = String( bytes:[data[63]], encoding:.utf8)
        elements[Passport.gender] = String( bytes:[data[64]], encoding:.utf8)
        elements[Passport.documentExpiryDate]   = String( bytes:data[65..<71], encoding:.utf8)
        elements[Passport.documentExpiryDateCheckDigit] = String( bytes:[data[71]], encoding:.utf8)
        elements[Passport.personalNumber]   = String( bytes:data[72..<86], encoding:.utf8)
        elements[Passport.personalNumberCheckDigit] = String( bytes:[data[86]], encoding:.utf8)
        elements[Passport.mrzLineCheckDigit] = String( bytes:[data[87]], encoding:.utf8)
    }
    
    private func getMRZType(length: Int) -> DocTypeEnum {
        if length == 0x5A {
            return .TD1
        }
        if length == 0x48 {
            return .TD2
        }
        return .OTHER
    }
    
    
    // MARK: - Parsing Drivers License (EU DL)
    private func parseDriversTag(for nextTag: Int) throws {
        let body = try getNextValue()
        let currentElement = intToHex(nextTag)
        Log.info("DG1 - Data Elements - \(currentElement)")
        
        let dateTags = [DriverLicense.dateOfBirth, DriverLicense.dateOfIssue, DriverLicense.dateOfExpiry].map { $0.intHex }
        elements[currentElement] = dateTags.contains { $0 == nextTag } ? parseDate(body) : parseString(body)
        
        try handleNextTag()
    }
    
    private func handleNextTag() throws {
        let nextTag = try getNextTag()
        
        guard nextTag != 0x5F02 else {
            return try parseGender()
        }
        
        guard nextTag != 0x7F63 else {
            let length = try getNextLength()
            let body = [UInt8](data[pos..<pos+length])
            return try parseLicenseCategories(body)
        }
        
        guard nextTag != 0 else { return }
        try parseDriversTag(for: nextTag)
    }
    
    // Gender TagId - 0x5F02
    private func parseGender() throws {
        elements["5F02"] = parseString([data[pos]])
        pos += 1 // Move onto next tagId
        try handleNextTag()
    }
    
    // License Categories TagId - 0x7F63
    private func parseLicenseCategories(_ tagData: [UInt8]) throws {
        // TODO: parse categories
        Log.debug("DG1 - License Categories - 7F63 - \(binToHexRep(tagData))")
    }
    
    private func parseString(_ tagData: [UInt8]) -> String? {
        return String(bytes: tagData, encoding: .windowsCP1250)
    }
    
    private func parseDate(_ tagData: [UInt8]) -> String {
        return binToHexRep(tagData)
    }
}
