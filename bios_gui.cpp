#include <QApplication>
#include <QMainWindow>
#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QTextEdit>
#include <QPushButton>
#include <QLabel>
#include <QGroupBox>
#include <QTimer>
#include <QFont>
#include <QKeyEvent>
#include <QFileDialog>
#include <QMessageBox>
#include <QScrollBar>
#include <queue>
#include "cpu8085.h"

// Interactive terminal widget that handles keyboard input
class TerminalWidget : public QTextEdit {
    Q_OBJECT

private:
    std::queue<uint8_t> inputBuffer;
    bool inputEnabled;

public:
    TerminalWidget(QWidget *parent = nullptr) : QTextEdit(parent), inputEnabled(true) {
        setFont(QFont("Monospace", 10));
        setReadOnly(false);  // Allow typing
        setUndoRedoEnabled(false);
    }

    void appendOutput(const QString& text) {
        moveCursor(QTextCursor::End);
        insertPlainText(text);
        moveCursor(QTextCursor::End);
        verticalScrollBar()->setValue(verticalScrollBar()->maximum());
    }

    bool hasInput() const {
        return !inputBuffer.empty();
    }

    uint8_t readInput() {
        if (inputBuffer.empty()) return 0;
        uint8_t ch = inputBuffer.front();
        inputBuffer.pop();
        return ch;
    }

protected:
    void keyPressEvent(QKeyEvent *event) override {
        if (!inputEnabled) return;

        QString text = event->text();
        if (!text.isEmpty()) {
            QChar ch = text.at(0);
            if (ch.isPrint() || ch == '\r' || ch == '\n') {
                // Don't echo - let BIOS handle echoing
                if (ch == '\r' || ch == '\n') {
                    inputBuffer.push('\r');  // BIOS expects CR
                } else {
                    inputBuffer.push(ch.toLatin1());
                }
            }
        } else if (event->key() == Qt::Key_Backspace) {
            // Handle backspace - BIOS should handle echo
            inputBuffer.push(0x08);  // Send backspace to BIOS
        }
    }
};

class BIOSEmulatorWindow : public QMainWindow {
    Q_OBJECT

private:
    CPU8085 *cpu;
    TerminalWidget *terminal;
    QTextEdit *registerDisplay;
    QTextEdit *flagsDisplay;
    QTextEdit *memoryDisplay;
    QTimer *runTimer;
    bool running;

public:
    BIOSEmulatorWindow(QWidget *parent = nullptr) : QMainWindow(parent), running(false) {
        setMinimumSize(1200, 800);
        
        cpu = new CPU8085();
        updateWindowTitle();  // Call after CPU is created
        
        // Setup I/O callbacks
        cpu->setIOCallbacks(
            // IN callback (port 0 = console input)
            [this](uint8_t port) -> uint8_t {
                if (port == 0) {
                    return terminal->hasInput() ? terminal->readInput() : 0;
                }
                return 0xFF;
            },
            // OUT callback (port 1 = console output)
            [this](uint8_t port, uint8_t value) {
                if (port == 1) {
                    terminal->appendOutput(QString(QChar(value)));
                }
            }
        );
        
        // Central widget
        QWidget *centralWidget = new QWidget(this);
        setCentralWidget(centralWidget);
        
        QHBoxLayout *mainLayout = new QHBoxLayout(centralWidget);
        
        // Left panel - Terminal (larger)
        QVBoxLayout *leftLayout = new QVBoxLayout();
        
        QGroupBox *terminalGroup = new QGroupBox("8085 Console Terminal");
        QVBoxLayout *terminalLayout = new QVBoxLayout();
        terminal = new TerminalWidget();
        terminal->setMinimumSize(600, 400);
        terminal->setPlaceholderText("BIOS output will appear here...\nType commands when BIOS prompt appears.");
        terminalLayout->addWidget(terminal);
        terminalGroup->setLayout(terminalLayout);
        leftLayout->addWidget(terminalGroup, 4);
        
        // Memory viewer
        QGroupBox *memoryGroup = new QGroupBox("Memory Viewer (0x0000-0x00FF)");
        QVBoxLayout *memoryLayout = new QVBoxLayout();
        memoryDisplay = new QTextEdit();
        memoryDisplay->setReadOnly(true);
        memoryDisplay->setFont(QFont("Monospace", 9));
        memoryDisplay->setMinimumHeight(150);
        memoryLayout->addWidget(memoryDisplay);
        memoryGroup->setLayout(memoryLayout);
        leftLayout->addWidget(memoryGroup, 1);
        
        mainLayout->addLayout(leftLayout, 3);
        
        // Right panel - Registers and Controls
        QVBoxLayout *rightLayout = new QVBoxLayout();
        
        // Register display
        QGroupBox *registerGroup = new QGroupBox("Registers");
        QVBoxLayout *registerLayout = new QVBoxLayout();
        registerDisplay = new QTextEdit();
        registerDisplay->setReadOnly(true);
        registerDisplay->setMinimumHeight(120);
        registerDisplay->setFont(QFont("Monospace", 10));
        registerLayout->addWidget(registerDisplay);
        registerGroup->setLayout(registerLayout);
        rightLayout->addWidget(registerGroup);
        
        // Flags display
        QGroupBox *flagsGroup = new QGroupBox("Flags");
        QVBoxLayout *flagsLayout = new QVBoxLayout();
        flagsDisplay = new QTextEdit();
        flagsDisplay->setReadOnly(true);
        flagsDisplay->setMinimumHeight(60);
        flagsDisplay->setFont(QFont("Monospace", 10));
        flagsLayout->addWidget(flagsDisplay);
        flagsGroup->setLayout(flagsLayout);
        rightLayout->addWidget(flagsGroup);
        
        // Control buttons
        QGroupBox *controlGroup = new QGroupBox("Controls");
        QVBoxLayout *controlLayout = new QVBoxLayout();
        
        QPushButton *loadBiosBtn = new QPushButton("Load BIOS");
        QPushButton *resetBtn = new QPushButton("Reset CPU");
        QPushButton *stepBtn = new QPushButton("Step (F8)");
        QPushButton *runBtn = new QPushButton("Run (F5)");
        QPushButton *stopBtn = new QPushButton("Stop (F6)");
        QPushButton *loadProgBtn = new QPushButton("Load Program...");
        
        connect(loadBiosBtn, &QPushButton::clicked, this, &BIOSEmulatorWindow::onLoadBIOS);
        connect(resetBtn, &QPushButton::clicked, this, &BIOSEmulatorWindow::onReset);
        connect(stepBtn, &QPushButton::clicked, this, &BIOSEmulatorWindow::onStep);
        connect(runBtn, &QPushButton::clicked, this, &BIOSEmulatorWindow::onRun);
        connect(stopBtn, &QPushButton::clicked, this, &BIOSEmulatorWindow::onStop);
        connect(loadProgBtn, &QPushButton::clicked, this, &BIOSEmulatorWindow::onLoadProgram);
        
        loadBiosBtn->setMinimumHeight(35);
        resetBtn->setMinimumHeight(35);
        stepBtn->setMinimumHeight(35);
        runBtn->setMinimumHeight(35);
        stopBtn->setMinimumHeight(35);
        loadProgBtn->setMinimumHeight(35);
        
        controlLayout->addWidget(loadBiosBtn);
        controlLayout->addWidget(resetBtn);
        controlLayout->addWidget(stepBtn);
        controlLayout->addWidget(runBtn);
        controlLayout->addWidget(stopBtn);
        controlLayout->addWidget(loadProgBtn);
        controlLayout->addStretch();
        
        controlGroup->setLayout(controlLayout);
        rightLayout->addWidget(controlGroup);
        
        mainLayout->addLayout(rightLayout, 1);
        
        // Run timer for continuous execution
        runTimer = new QTimer(this);
        connect(runTimer, &QTimer::timeout, this, &BIOSEmulatorWindow::onRunStep);
        
        updateDisplays();
        
        terminal->appendOutput("8085 BIOS System Ready\n");
        terminal->appendOutput("Click 'Load BIOS' to load the monitor ROM\n\n");
    }

    void updateWindowTitle() {
        int bank = cpu ? cpu->getCurrentBank() : 0;
        setWindowTitle(QString("8085 BIOS System - Bank %1/7 (512KB Total)")
                        .arg(bank));
    }

private slots:
    void onLoadBIOS() {
        const char* biosPath = "build/bios.bin";
        if (cpu->loadBinary(biosPath, 0x0000)) {
            cpu->PC = 0x0000;
            terminal->appendOutput("\n=== BIOS loaded at 0x0000 ===\n");
            terminal->appendOutput("Press 'Run' or 'Step' to start\n\n");
            updateDisplays();
            updateWindowTitle();
        } else {
            QMessageBox::warning(this, "Error", 
                "Could not load BIOS from build/bios.bin\n"
                "Please build the BIOS first:\n  make -C /path/to/8085_bios");
        }
    }

    void onReset() {
        cpu->reset();
        // Reload BIOS if it was loaded
        cpu->loadBinary("build/bios.bin", 0x0000);
        cpu->PC = 0x0000;
        terminal->clear();
        terminal->appendOutput("=== CPU Reset ===\n\n");
        updateDisplays();
    }

    void onStep() {
        if (!cpu->halted) {
            cpu->step();
            updateDisplays();
        }
    }

    void onRun() {
        if (!running) {
            running = true;
            runTimer->start(1);  // Execute steps as fast as possible
        }
    }

    void onStop() {
        running = false;
        runTimer->stop();
        updateDisplays();
    }

    void onRunStep() {
        if (!cpu->halted) {
            // Execute multiple instructions per timer tick for speed
            for (int i = 0; i < 1000 && !cpu->halted; i++) {
                cpu->step();
            }
            updateDisplays();
            updateWindowTitle();  // Update bank display
        } else {
            onStop();
        }
    }

    void onLoadProgram() {
        QString filename = QFileDialog::getOpenFileName(this, 
            "Load Program Binary", "", "Binary Files (*.bin *.rom);;All Files (*)");
        
        if (!filename.isEmpty()) {
            uint16_t addr = 0x2000;  // Load user programs at 0x2000 by default
            if (cpu->loadBinary(filename.toStdString().c_str(), addr)) {
                terminal->appendOutput(QString("\n=== Program loaded at 0x%1 ===\n")
                    .arg(addr, 4, 16, QChar('0')));
                terminal->appendOutput("Use BIOS 'G' command to jump to it\n\n");
                updateDisplays();
            } else {
                QMessageBox::warning(this, "Error", "Could not load program file");
            }
        }
    }

    void updateDisplays() {
        registerDisplay->setPlainText(QString::fromStdString(cpu->getRegisterState()));
        flagsDisplay->setPlainText(QString::fromStdString(cpu->getFlagsState()));
        
        // Update memory viewer
        QString memText;
        for (int row = 0; row < 16; row++) {
            memText += QString("%1: ").arg(row * 16, 4, 16, QChar('0')).toUpper();
            for (int col = 0; col < 16; col++) {
                uint16_t addr = row * 16 + col;
                memText += QString("%1 ").arg(cpu->getMemory(addr), 2, 16, QChar('0')).toUpper();
            }
            memText += "\n";
        }
        memoryDisplay->setPlainText(memText);
    }
};

#include "bios_gui.moc"

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);
    BIOSEmulatorWindow window;
    window.show();
    return app.exec();
}
