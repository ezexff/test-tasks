#include <windows.h>

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

static OPENFILENAMEA OpenFileName = {};
static char FileName[256];

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR pCmdLine, int nCmdShow)
{
    // Register the window class.
    const char CLASS_NAME[]  = "Sample Window Class";
    
    WNDCLASSA wc = { };

    wc.lpfnWndProc   = WindowProc;
    wc.hInstance     = hInstance;
    wc.lpszClassName = CLASS_NAME;

    RegisterClassA(&wc);

    // Create the window.

    HWND hwnd = CreateWindowExA(
        0,                              // Optional window styles.
        CLASS_NAME,                     // Window class
        "Learn to Program Windows",    // Window text
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,            // Window style

        // Size and position
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,

        NULL,       // Parent window    
        NULL,       // Menu
        hInstance,  // Instance handle
        NULL        // Additional application data
        );

    int Check = WS_OVERLAPPEDWINDOW;
    Check = CW_USEDEFAULT;
    Check = ES_AUTOHSCROLL;
    Check = WS_OVERLAPPEDWINDOW | WS_VISIBLE;

    if (hwnd == NULL)
    {
        return 0;
    }

    OpenFileName.lStructSize = sizeof(OpenFileName);
    OpenFileName.hwndOwner = hwnd;
    OpenFileName.lpstrFile = (LPSTR)FileName;
    OpenFileName.nMaxFile = sizeof(FileName);
    OpenFileName.lpstrFilter = ".txt";
    OpenFileName.lpstrFileTitle = 0;
    OpenFileName.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

    int Check2 = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;
    int Test = sizeof(OPENFILENAMEA);

    HWND Button = CreateWindowExA(
        0,                              // Optional window styles.
        "Button",                     // Window class
        "Click on me!",    // Window text
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,            // Window style

        // Size and position
        0, 0, 150, 15,

        hwnd,       // Parent window    
        (HMENU)1,       // Menu
        0,  // Instance handle
        0        // Additional application data
    );

    Check = WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON;

    HWND Text123 = CreateWindowExA(
        WS_EX_CLIENTEDGE,
        "static",
        "FDSFKLSDJFSDLKFSJLK!",
        WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOVSCROLL | ES_MULTILINE,
        50, 50, 200, 100,
        hwnd,
        NULL,
        0,
        NULL
    );

    Check = WS_CHILD | WS_VISIBLE | WS_BORDER | ES_AUTOVSCROLL | ES_MULTILINE;
    Check = WM_PAINT;

    ShowWindow(hwnd, nCmdShow);

    // Run the message loop.

    MSG msg = { };
    while (GetMessageA(&msg, NULL, 0, 0) > 0)
    {
        //TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return 0;
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    switch (uMsg)
    {
    case WM_CREATE:
    {
        break;
    }
    case WM_DESTROY:
    {
        PostQuitMessage(0);
        return 0;
    }
    case WM_COMMAND:
    {

        switch (LOWORD(wParam)) {
        case 1:
            // code block

            if (GetOpenFileNameA(&OpenFileName))
            {
                MessageBox(0, OpenFileName.lpstrFile, "File loaded", MB_OK);
            }
            break;

        case 2:

            // code block
            break;

        default:
            break;
            // code block
        }

        break;
    }
    case WM_PAINT:
    {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);

        // All painting occurs here, between BeginPaint and EndPaint.

        FillRect(hdc, &ps.rcPaint, (HBRUSH)(COLOR_WINDOW + 1));

        EndPaint(hwnd, &ps);
        break;
    }

    }
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}