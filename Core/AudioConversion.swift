import AVFoundation

public enum AudioConversionError: Error {case unsupported,empty}
public enum AudioConversion {
    public static func convert(_ input:AVAudioPCMBuffer,to format:AVAudioFormat) throws -> AVAudioPCMBuffer {
        if input.format == format {return input}
        guard let converter=AVAudioConverter(from:input.format,to:format),
              let output=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(ceil(Double(input.frameLength)*format.sampleRate/input.format.sampleRate)+32)) else {
            throw AudioConversionError.unsupported
        }
        var supplied=false
        var error:NSError?
        let status=converter.convert(to:output,error:&error) {_,state in
            if supplied {state.pointee = .endOfStream;return nil}
            supplied=true;state.pointee = .haveData;return input
        }
        if let error {throw error}
        guard status != .error,output.frameLength > 0 else {throw AudioConversionError.empty}
        return output
    }
}
