#ifndef CPU8085_H
#define CPU8085_H

#include <cstdint>
#include <array>
#include <string>
#include <functional>

// I/O port callback types
using IOReadCallback = std::function<uint8_t(uint8_t port)>;
using IOWriteCallback = std::function<void(uint8_t port, uint8_t value)>;

// Intel 8085 model with banked memory and callback-based I/O devices.
class CPU8085 {
public:
    // Programmer-visible registers.
    uint8_t A;      // Accumulator
    uint8_t B, C;   // BC register pair
    uint8_t D, E;   // DE register pair
    uint8_t H, L;   // HL register pair
    uint16_t SP;    // Stack Pointer
    uint16_t PC;    // Program Counter
    
    // 8085 condition flags.
    struct Flags {
        bool S;  // Sign
        bool Z;  // Zero
        bool AC; // Auxiliary Carry
        bool P;  // Parity
        bool CY; // Carry
    } flags;
    
    // Eight independently allocated 64 KiB banks; only current_bank is active.
    static constexpr int NUM_BANKS = 8;
    uint8_t* memory_banks[NUM_BANKS];  // Pointers to heap-allocated banks
    int current_bank;
    
    // Execution state.
    bool halted;
    bool interruptEnabled;
    
    CPU8085();
    ~CPU8085();

    // Restore registers, flags, banks, and execution state.
    void reset();

    // Fetch and execute one opcode unless halted.
    void step();
    uint8_t fetchByte();
    uint16_t fetchWord();
    
    // Human-readable state used by the Qt debugger.
    std::string getRegisterState() const;
    std::string getFlagsState() const;
    uint8_t getMemory(uint16_t address) const;
    void setMemory(uint16_t address, uint8_t value);
    
    // Select and inspect the active or an explicitly named memory bank.
    void switchBank(int bank);
    int getCurrentBank() const { return current_bank; }
    uint8_t getMemoryFromBank(int bank, uint16_t address) const;
    void setMemoryInBank(int bank, uint16_t address, uint8_t value);
    
    // Copy bytes into the active bank.
    void loadProgram(const uint8_t* program, size_t size, uint16_t startAddress = 0x0000);
    
    // Load a host binary file into the active bank.
    bool loadBinary(const char* filename, uint16_t startAddress = 0x0000);
    
    // Device callbacks invoked by IN and OUT instructions.
    IOReadCallback ioReadCallback;
    IOWriteCallback ioWriteCallback;
    
    // Replace the device callbacks.
    void setIOCallbacks(IOReadCallback readCb, IOWriteCallback writeCb) {
        ioReadCallback = readCb;
        ioWriteCallback = writeCb;
    }
    
private:
    void executeInstruction(uint8_t opcode);
    void updateFlags(uint8_t result);
    void updateFlagsLogical(uint8_t result);
    uint8_t add(uint8_t value, bool withCarry = false);
    uint8_t sub(uint8_t value, bool withBorrow = false);
    void push(uint16_t value);
    uint16_t pop();
    
    // Helper methods for register pairs
    uint16_t getBC() const { return (B << 8) | C; }
    uint16_t getDE() const { return (D << 8) | E; }
    uint16_t getHL() const { return (H << 8) | L; }
    void setBC(uint16_t val) { B = (val >> 8) & 0xFF; C = val & 0xFF; }
    void setDE(uint16_t val) { D = (val >> 8) & 0xFF; E = val & 0xFF; }
    void setHL(uint16_t val) { H = (val >> 8) & 0xFF; L = val & 0xFF; }
};

#endif // CPU8085_H
