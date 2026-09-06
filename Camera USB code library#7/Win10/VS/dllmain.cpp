#include "pch.h"

#include <windows.h>
#include <initguid.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>

#pragma comment(lib, "mf.lib")
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")

// Variables globales pour la gestion du flux vidéo и des ressources COM
static IMFSourceReader* g_pReader = NULL;
static IMFMediaSource* g_pSource = NULL;
static HWND             g_hWndOwner = NULL;
static UINT_PTR         g_nTimerId = 0;
static BOOL             g_bCapturing = FALSE;
static BOOL             g_bTakePhoto = FALSE;

static LONG             g_frameWidth = 640;
static LONG             g_frameHeight = 480;
static BITMAPINFOHEADER g_bmiHeader = { 0 };

// Enregistre l'image du flux vidéo courant dans un fichier au format BMP
static void SaveBitmapToFile(BYTE* pData, DWORD dataSize, LONG width, LONG height) {
    HANDLE hFile = CreateFileA("photo.bmp", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) return;

    BITMAPFILEHEADER bfh = { 0 };
    bfh.bfType = 0x4D42; // En-tête de fichier BMP "BM"
    bfh.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
    bfh.bfSize = bfh.bfOffBits + dataSize;

    BITMAPINFOHEADER bih = { 0 };
    bih.biSize = sizeof(BITMAPINFOHEADER);
    bih.biWidth = width;
    bih.biHeight = -height; // Hauteur négative pour corriger l'orientation verticale
    bih.biPlanes = 1;
    bih.biBitCount = 32;
    bih.biCompression = BI_RGB;
    bih.biSizeImage = dataSize;

    DWORD written = 0;
    WriteFile(hFile, &bfh, sizeof(bfh), &written, NULL);
    WriteFile(hFile, &bih, sizeof(bih), &written, NULL);
    WriteFile(hFile, pData, dataSize, &written, NULL);
    CloseHandle(hFile);
}

// Procédure de rappel du minuteur pour la capture et le rendu de chaque image
VOID CALLBACK TimerProc(HWND hwnd, UINT uMsg, UINT_PTR idEvent, DWORD dwTime) {
    if (!g_bCapturing || !g_pReader) return;

    IMFSample* pSample = NULL;
    DWORD flags = 0;
    LONGLONG timestamp = 0;

    // Lecture de l'échantillon vidéo depuis Media Foundation
    HRESULT hr = g_pReader->ReadSample(
        (DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM,
        0, NULL, &flags, &timestamp, &pSample
    );

    if (SUCCEEDED(hr) && pSample) {
        IMFMediaBuffer* pBuffer = NULL;
        if (SUCCEEDED(pSample->ConvertToContiguousBuffer(&pBuffer))) {
            BYTE* pData = NULL;
            DWORD maxLen = 0, curLen = 0;
            if (SUCCEEDED(pBuffer->Lock(&pData, &maxLen, &curLen))) {

                // Rendu graphique dans le contrôle d'affichage de la fenêtre parent
                HDC hdc = GetDC(g_hWndOwner);
                if (hdc) {
                    RECT rc;
                    GetClientRect(g_hWndOwner, &rc);
                    int dstW = rc.right - rc.left;
                    int dstH = rc.bottom - rc.top;

                    SetStretchBltMode(hdc, COLORONCOLOR);
                    StretchDIBits(
                        hdc, 0, 0, dstW, dstH,
                        0, 0, g_frameWidth, g_frameHeight,
                        pData, (BITMAPINFO*)&g_bmiHeader, DIB_RGB_COLORS, SRCCOPY
                    );
                    ReleaseDC(g_hWndOwner, hdc);
                }

                // Capture de l'image si la demande a été déclenchée
                if (g_bTakePhoto) {
                    SaveBitmapToFile(pData, curLen, g_frameWidth, g_frameHeight);
                    g_bTakePhoto = FALSE;
                    MessageBoxA(g_hWndOwner, "Photo enregistrée dans photo.bmp !", "Succès", MB_ICONINFORMATION);
                }

                pBuffer->Unlock();
            }
            pBuffer->Release();
        }
        pSample->Release();
    }
}

// Initialise Media Foundation et démarre la capture vidéo
extern "C" __declspec(dllexport) BOOL __stdcall StartCameraCapture(HWND hWndParent) {
    if (g_bCapturing) return TRUE;

    // Initialisation de la bibliothèque COM
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);

    if (FAILED(MFStartup(MF_VERSION))) return FALSE;

    IMFAttributes* pAttributes = NULL;
    if (FAILED(MFCreateAttributes(&pAttributes, 1))) return FALSE;

    pAttributes->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE, MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);

    IMFActivate** ppDevices = NULL;
    UINT32 count = 0;
    HRESULT hr = MFEnumDeviceSources(pAttributes, &ppDevices, &count);
    pAttributes->Release();

    if (FAILED(hr) || count == 0) return FALSE;

    // Énumération des périphériques vidéo disponibles
    g_pSource = NULL;
    for (UINT32 i = 0; i < count; i++) {
        if (!g_pSource) {
            MFCreateDeviceSource(ppDevices[i], &g_pSource);
        }
        ppDevices[i]->Release();
    }
    CoTaskMemFree(ppDevices);

    if (!g_pSource) return FALSE;

    // Activation du processeur vidéo interne pour la conversion automatique de format
    IMFAttributes* pReaderAttributes = NULL;
    MFCreateAttributes(&pReaderAttributes, 1);
    pReaderAttributes->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);

    hr = MFCreateSourceReaderFromMediaSource(g_pSource, pReaderAttributes, &g_pReader);
    pReaderAttributes->Release();

    if (FAILED(hr)) return FALSE;

    // Configuration du format de sortie en RGB32
    IMFMediaType* pType = NULL;
    MFCreateMediaType(&pType);
    pType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
    pType->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_RGB32);

    hr = g_pReader->SetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, NULL, pType);
    pType->Release();

    if (FAILED(hr)) return FALSE;

    // Récupération des dimensions réelles du flux vidéo
    IMFMediaType* pCurrentType = NULL;
    if (SUCCEEDED(g_pReader->GetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_VIDEO_STREAM, &pCurrentType))) {
        UINT32 w = 0, h = 0;
        MFGetAttributeSize(pCurrentType, MF_MT_FRAME_SIZE, &w, &h);
        if (w > 0 && h > 0) {
            g_frameWidth = (LONG)w;
            g_frameHeight = (LONG)h;
        }
        pCurrentType->Release();
    }

    // Configuration de l'en-tête d'affichage DIB
    ZeroMemory(&g_bmiHeader, sizeof(g_bmiHeader));
    g_bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    g_bmiHeader.biWidth = g_frameWidth;
    g_bmiHeader.biHeight = -g_frameHeight;
    g_bmiHeader.biPlanes = 1;
    g_bmiHeader.biBitCount = 32;
    g_bmiHeader.biCompression = BI_RGB;

    g_hWndOwner = hWndParent;
    g_bCapturing = TRUE;

    // Démarrage du minuteur à environ 30 images par seconde
    g_nTimerId = SetTimer(NULL, 0, 33, TimerProc);
    return TRUE;
}

// Signale qu'une photo doit être prise à la prochaine image reçue
extern "C" __declspec(dllexport) VOID __stdcall TakeCameraPhoto() {
    if (g_bCapturing) {
        g_bTakePhoto = TRUE;
    }
}

// Arrête la capture et libère toutes les ressources allouées
extern "C" __declspec(dllexport) VOID __stdcall StopCameraCapture() {
    if (!g_bCapturing) return;

    if (g_nTimerId) {
        KillTimer(NULL, g_nTimerId);
        g_nTimerId = 0;
    }

    g_bCapturing = FALSE;

    if (g_pReader) { g_pReader->Release(); g_pReader = NULL; }
    if (g_pSource) { g_pSource->Release(); g_pSource = NULL; }

    MFShutdown();
    CoUninitialize();
}