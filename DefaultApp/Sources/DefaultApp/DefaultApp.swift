import SwiftIO

import MadBoard
import ST7789

import MadGraphics

let a0Module = 0
let d1Module = 1
let a11Module = 2
let d19Module = 3


let temperature = 5
let humidityKey = 6

let accValue = 8



var globalIOValue: [Int: Int] = [
    a0Module: -1,
    d1Module: -1,
    a11Module: -1,
    d19Module: -1,
]
let ioLock = Mutex()


var globalI2CValue: [Int: Int] = [
    temperature: -1,
    humidityKey: -1,
    accValue: -1,
]
let i2cLock = Mutex()





@main
public struct DefaultApp {
    public static func main() {
        sleep(ms: 100)

        let red = DigitalOut(Id.RED, value: true)
        let green = DigitalOut(Id.GREEN, value: true)
        let blue = DigitalOut(Id.BLUE, value: true)

        let led = PWMOut(Id.PWM4A)
        led.set(frequency: 2000, dutycycle: 0.0)
        let buzzer = PWMOut(Id.PWM5A)

        let spi = SPI(Id.SPI0, speed: 30_000_000)

        let bl = DigitalOut(Id.D2)
        let rst = DigitalOut(Id.D12)
        let dc = DigitalOut(Id.D13)
        let cs = DigitalOut(Id.D5)

        let screen = ST7789(spi: spi, cs: cs, dc: dc, rst: rst, bl: bl, width: 240, rotation: .angle90)
        var frameBuffer = [UInt16](repeating: 0, count: 240 * 240)

        var fileLength = 0
        guard let fontDataBuffer = openFile(path: "/lfs/Resources/Fonts/Roboto-Regular.ttf", length: &fileLength) else {
        //guard let fontDataBuffer = openFile(path: "/lfs/Resources/Fonts/Roboto-Italic.ttf", length: &fileLength) else {
            while true {
                red.toggle()
                sleep(ms: 200)
                red.toggle()
                sleep(ms: 200)
            }
        }

        green.low()




        let colors = [
            Color.black,
            Color.gray,
            Color.silver,
            Color.red,
            Color.pink,
            Color.maroon,
            Color.lime,
            Color.green,
            Color.olive,
            Color.blue,
            Color.navy,
            Color.teal,
            Color.cyan,
            Color.aqua,
            Color.purple,
            Color.magenta,
            Color.orange,
            Color.yellow,
            Color.white,
        ]
        var colorIndex = 0

        var uptime = getSystemUptimeInMilliseconds() / 1000
        let normalFont = Font(from: fontDataBuffer, length: fileLength, pointSize: 6, dpi: 220)
        let largeFont = Font(from: fontDataBuffer, length: fileLength, pointSize: 10, dpi: 220)

        let canvas = Canvas(width: 240, height: 240)
        displayInit(canvas, fontBuffer: fontDataBuffer, length: fileLength)
        updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)

        let soundState = normalFont.getMask("Play sound")

        createThread(
            name: "play_sound",
            priority: 3,
            stackSize: 1024 * 64,
            soundThread
        )
        sleep(ms: 10)

        createThread(
            name: "normal_io",
            priority: 4,
            stackSize: 1024 * 64,
            ioThread
        )
        sleep(ms: 10)

        createThread(
            name: "i2c_io",
            priority: 5,
            stackSize: 1024 * 64,
            i2cIOThread
        )
        sleep(ms: 10)




        while true {
            sleep(ms: 5)
            green.toggle()

            ioLock.lock()
            let ioSendState = globalIOValue.filter { (step, value) in
                value >= 0
            }
            ioLock.unlock()

            for (key, value) in ioSendState {
                if key == a0Module {
                    let dutycycle = Float(value) / 100.0
                    led.setDutycycle(dutycycle)
                    canvas.fillRectangle(at: Point(x: 10, y: 106), width: 100, height: 28, color: Color.white)
                    if value != 0 {
                        canvas.fillRectangle(at: Point(x: 10, y: 106), width: value, height: 28, color: Color(0xFF5E5E))
                    }
                    updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
                }

                if key == a11Module {
                    let fre = 400 + 40 * value
                    if value > 1 {
                        buzzer.set(frequency: fre, dutycycle: 0.5)
                    } else {
                        buzzer.set(frequency: fre, dutycycle: 0)
                    }
                    canvas.fillRectangle(at: Point(x: 130, y: 106), width: 100, height: 28, color: Color.white)
                    if value != 0 {
                        canvas.fillRectangle(at: Point(x: 130, y: 106), width: value, height: 28, color: Color(0xFFF568))
                    }
                    updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
                }

                if key == d1Module {
                    let color = colors[colorIndex]
                    canvas.fillRectangle(at: Point(x: 10, y: 185), width: 100, height: 30, color: color) 
                    updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
                    colorIndex += 1
                    if colorIndex >= colors.count {
                        colorIndex = 0
                    }
                }

                if key == d19Module && value == 2 {
                    canvas.fillRectangle(at: Point(x: 124, y: 42), width: 100, height: 18, color: Color.white) 
                    canvas.blend(from: soundState, foreground: Color.lime, to: Point(x: 124, y: 42))
                    updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
                }

                if key == d19Module && value == 0 {
                    canvas.fillRectangle(at: Point(x: 124, y: 42), width: 100, height: 18, color: Color.white) 
                    canvas.blend(from: soundState, foreground: Color.red, to: Point(x: 124, y: 42))
                    updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
                }
            }

            ioLock.lock()
            for (key, value) in ioSendState {
                if key == d19Module {
                    if value == 2 || value == 0 {
                        globalIOValue[key]! -= 1
                    }
                } else {
                    globalIOValue[key] = -1
                }
            }
            ioLock.unlock()


            i2cLock.lock()
            let i2cSendState = globalI2CValue.filter { (step, value) in
                value >= 0
            }
            i2cLock.unlock()

            for (key, value) in i2cSendState {

                if key == temperature {
                    let valueText = String(Float(value) / 10.0) + "°C"
                    let text = largeFont.getMask(valueText)

                    canvas.fillRectangle(at: Point(x: 10, y: 12), width: 100, height: 30, color: Color.white)
                    canvas.blend(from: text, foreground: Color(0x39E910), to: Point(x: 10, y: 12))
                    updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
                }

                if key == humidityKey {
                    let valueText = String(Float(value) / 10.0) + "%"
                    let text = largeFont.getMask(valueText)

                    canvas.fillRectangle(at: Point(x: 10, y: 48), width: 100, height: 30, color: Color.white)
                    canvas.blend(from: text, foreground: Color(0x1e9cf4), to: Point(x: 10, y: 48))
                    updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
                }

                if key == accValue {
                    let previousX = (value >> 8) & 0xFF
                    let x = value & 0xFF

                    canvas.fillRectangle(at: Point(x: previousX + 130, y: 186), width: 5, height: 27, color: Color.white)
                    canvas.fillRectangle(at: Point(x: x + 130, y: 186), width: 5, height: 27, color: Color.orange)
                    updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
                }
            }

            i2cLock.lock()
            for key in i2cSendState.keys {
                globalI2CValue[key] = -1
            }
            i2cLock.unlock()











            let currentTime = getSystemUptimeInMilliseconds() / 1000
            if uptime != currentTime {
                uptime = currentTime
                let hour = uptime / 3600
                let minute = (uptime / 60) % 60
                let second = uptime % 60

                let hourStr = (hour < 10 ? String(0) + String(hour) : String(hour)) + ":"               
                let minStr = (minute < 10 ? String(0) + String(minute) : String(minute)) + ":"               
                let secStr = (second < 10 ? String(0) + String(second) : String(second))            

                let timeText = normalFont.getMask(hourStr + minStr + secStr)
                canvas.fillRectangle(at: Point(x: 124, y: 22), width: 100, height: 15, color: Color.white)
                canvas.blend(from: timeText, foreground: Color.purple, to: Point(x: 124, y: 22))
                updateDisplay(canvas: canvas, frameBuffer: &frameBuffer, screen: screen)
            }
        }



    }
}





func displayInit(_ canvas: Canvas, fontBuffer: UnsafeMutableRawBufferPointer, length: Int) {
    canvas.fill(Color.white)
    canvas.drawLine(from: Point(x: 120, y: 0), to: Point(x: 120, y: 239), stroke: 2, color: Color.pink)
    canvas.drawLine(from: Point(x: 120, y: 40), to: Point(x: 239, y: 40), stroke: 2, color: Color.pink)
    canvas.drawLine(from: Point(x: 0, y: 80), to: Point(x: 239, y: 80), stroke: 2, color: Color.pink)
    canvas.drawLine(from: Point(x: 0, y: 160), to: Point(x: 239, y: 160), stroke: 2, color: Color.pink)

    let blackFont = Font(from: fontBuffer, length: length, pointSize: 6, dpi: 220)
    let grayFont = Font(from: fontBuffer, length: length, pointSize: 5, dpi: 220)

    print("display init 0")
    let time = blackFont.getMask("Uptime")
    canvas.blend(from: time, foreground: Color.black, to: Point(x: 124, y: 2))

    print("display init 1")
    let sound = blackFont.getMask("Play sound")
    let soundAction = grayFont.getMask("Press Button D19")
    canvas.blend(from: sound, foreground: Color.red, to: Point(x: 124, y: 42))
    canvas.blend(from: soundAction, foreground: Color.gray, to: Point(x: 124, y: 65))

    print("display init 2")
    let led = blackFont.getMask("LED brightness")
    let ledAction = grayFont.getMask("Rotate Knob A0")
    canvas.blend(from: led, foreground: Color(0x252525), to: Point(x: 0, y: 82))
    canvas.blend(from: ledAction, foreground: Color.gray, to: Point(x: 0, y: 142))

    print("display init 3")
    let buzzer = blackFont.getMask("Buzzer pitch")
    let buzzerAction = grayFont.getMask("Rotate Knob A11")
    canvas.blend(from: buzzer, foreground: Color(0x252525), to: Point(x: 124, y: 82))
    canvas.blend(from: buzzerAction, foreground: Color.gray, to: Point(x: 124, y: 142))

    print("display init 4")
    let color = blackFont.getMask("Color picker")
    let colorAction = grayFont.getMask("Press Button D1")
    canvas.blend(from: color, foreground: Color(0x252525), to: Point(x: 0, y: 165))
    canvas.blend(from: colorAction, foreground: Color.gray, to: Point(x: 0, y: 225))

    print("display init 5")
    let acc = blackFont.getMask("Acceleration")
    let accAction = grayFont.getMask("Tilt the board")
    canvas.blend(from: acc, foreground: Color(0x252525), to: Point(x: 124, y: 165))
    canvas.blend(from: accAction, foreground: Color.gray, to: Point(x: 124, y: 225))

    print("display init 6")
    canvas.drawRectangle(at: Point(x: 10, y: 105), width: 100, height: 30, stroke: 3, color: Color(0x252525))
    canvas.drawRectangle(at: Point(x: 130, y: 105), width: 100, height: 30, stroke: 3, color: Color(0x252525))
    canvas.drawRectangle(at: Point(x: 130, y: 185), width: 100, height: 30, stroke: 2, color: Color(0x252525))
}

func updateDisplay(canvas: Canvas, frameBuffer: inout [UInt16], screen: ST7789) {
    guard let dirty = canvas.getDirtyRect() else {
        return
    }

    var index = 0
    let stride = canvas.width
    let canvasBuffer = canvas.buffer
    for y in dirty.y0..<dirty.y1 {
        for x in dirty.x0..<dirty.x1 {
            frameBuffer[index] = Color.getRGB565LE(canvasBuffer[y * stride + x])
            index += 1
        }
    }
    frameBuffer.withUnsafeBytes { ptr in
        screen.writeBitmap(x: dirty.x, y: dirty.y, width: dirty.width, height: dirty.height, data: ptr)
    }

    canvas.finishRefresh()
}



func openFile(path: String, length: inout Int) -> UnsafeMutableRawBufferPointer? {
    var fontDataBuffer: UnsafeMutableRawBufferPointer? = nil

    print("open file:")
    do {
        let file = try FileDescriptor.open(path, .readOnly)

        try file.seek(offset: 0, from: FileDescriptor.SeekOrigin.end)
        let bytes = try file.tell()
        fontDataBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bytes, alignment: 8)
        length = bytes

        try file.seek(offset: 0, from: FileDescriptor.SeekOrigin.start)
        try file.read(into: fontDataBuffer!, count: bytes)
        try file.close()
    } catch {
        print("Error, file handle error")
        if let buffer = fontDataBuffer {
            buffer.deallocate()
        }
        return nil
    }

    print("open file success")
    return fontDataBuffer
}