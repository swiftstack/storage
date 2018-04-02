extension WAL.Record: AnyDecodable, Encodable {
    enum CodingKeys: CodingKey {
        case key
        case action
        case object
    }

    init(from decoder: Decoder, typeAccessor: TypeAccessor) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(Storage.Key.self, forKey: .key)
        self.action = try container.decode(Action.self, forKey: .action)
        let objectDecoder = try container.superDecoder(forKey: .object)
        let type = try typeAccessor(self.key)
        self.object = try type.init(from: objectDecoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
        try container.encode(action, forKey: .action)
        let objectEncoder = container.superEncoder(forKey: .object)
        try object.encode(to: objectEncoder)
    }
}
