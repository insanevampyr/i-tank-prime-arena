/* 46I-1 disposable prerequisite ONLY. No character format or gameplay authority.
 * Build from reviewed source; direct executable, no shell or external DLL.
 * Fixed sentinel names and LOCALAPPDATA test prefix deliberately prevent routing
 * to production. No remove-then-move or copy/delete fallback exists.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <string.h>

#define CAP 65536
#define PATH_CAP 1024
static WCHAR directory[PATH_CAP];
static DWORD volume_serial;
static BYTE old_bytes[CAP], new_bytes[CAP], actual[CAP];
static BOOL api_called = FALSE, api_success = FALSE;
static DWORD readback_error = 0;

static int result(const char *state, const char *phase, DWORD error, int code) {
    printf("{\"protocol\":1,\"state\":\"%s\",\"phase\":\"%s\",\"win32_error\":%lu,\"api_called\":%s,\"api_success\":%s,\"readback_error\":%lu,\"power_loss_guaranteed\":false}\n",
           state, phase, (unsigned long)error, api_called ? "true" : "false",
           api_success ? "true" : "false", (unsigned long)readback_error);
    fflush(stdout);
    return code;
}

static void path(WCHAR *out, const WCHAR *name) {
    swprintf_s(out, PATH_CAP, L"%s\\%s", directory, name);
}

static BOOL context(const WCHAR *input) {
    WCHAR local[PATH_CAP], prefix[PATH_CAP], full[PATH_CAP], resolved[PATH_CAP];
    WCHAR volume[PATH_CAP], fs[32];
    DWORD n = GetEnvironmentVariableW(L"LOCALAPPDATA", local, PATH_CAP);
    if (!n || n >= PATH_CAP) return FALSE;
    swprintf_s(prefix, PATH_CAP, L"%s\\itank-storage-tests\\minimal46i1_", local);
    n = GetFullPathNameW(input, PATH_CAP, full, NULL);
    if (!n || n >= PATH_CAP || wcslen(full) >= MAX_PATH - 40 ||
        _wcsnicmp(full, prefix, wcslen(prefix)) ||
        wcschr(full + wcslen(prefix), L'\\') || wcschr(full + wcslen(prefix), L'/')) return FALSE;
    HANDLE h = CreateFileW(full, FILE_READ_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE,
                          NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (h == INVALID_HANDLE_VALUE) return FALSE;
    BY_HANDLE_FILE_INFORMATION info;
    BOOL ok = GetFileInformationByHandle(h, &info) && !(info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT);
    n = GetFinalPathNameByHandleW(h, resolved, PATH_CAP, FILE_NAME_NORMALIZED);
    CloseHandle(h);
    if (!ok || !n || n >= PATH_CAP || _wcsicmp(resolved, full) &&
        (wcsncmp(resolved, L"\\\\?\\", 4) || _wcsicmp(resolved + 4, full))) return FALSE;
    if (!GetVolumePathNameW(full, volume, PATH_CAP) || GetDriveTypeW(volume) != DRIVE_FIXED ||
        !GetVolumeInformationW(volume, NULL, 0, &volume_serial, NULL, NULL, fs, 32) || _wcsicmp(fs, L"NTFS")) return FALSE;
    wcscpy_s(directory, PATH_CAP, full);
    return TRUE;
}

/* Deny in-place writers; allow compatible readers and this native rename.
 * Reject reparse points, hardlinks, directories, other volumes and large input.
 */
static HANDLE open_file(const WCHAR *name, DWORD access, DWORD sharing) {
    WCHAR p[PATH_CAP]; path(p, name);
    HANDLE h = CreateFileW(p, access, sharing, NULL,
                          OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (h == INVALID_HANDLE_VALUE) return h;
    BY_HANDLE_FILE_INFORMATION info;
    if (!GetFileInformationByHandle(h, &info) ||
        info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY) ||
        info.nNumberOfLinks != 1 || info.dwVolumeSerialNumber != volume_serial ||
        info.nFileSizeHigh || info.nFileSizeLow > CAP) {
        CloseHandle(h); SetLastError(ERROR_INVALID_DATA); return INVALID_HANDLE_VALUE;
    }
    return h;
}

static BOOL bytes(HANDLE h, BYTE *out, DWORD *length) {
    LARGE_INTEGER zero; zero.QuadPart = 0;
    return SetFilePointerEx(h, zero, NULL, FILE_BEGIN) && ReadFile(h, out, CAP, length, NULL);
}

static BOOL read_name(const WCHAR *name, BYTE *out, DWORD *length) {
    /* Permit the still-held stage handle's WRITE/DELETE access during exact
     * post-move readback. That handle itself continues denying other writers.
     */
    HANDLE h = open_file(name, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE);
    if (h == INVALID_HANDLE_VALUE) return FALSE;
    BOOL ok = bytes(h, out, length);
    DWORD error = GetLastError(); CloseHandle(h); SetLastError(error);
    return ok;
}

/* Explicit diagnostic barriers, not a save journal. Termination is performed
 * externally by the test driver. Bound waiting cannot hang a future caller.
 */
static BOOL barrier(const WCHAR *requested, const WCHAR *at) {
    if (wcscmp(requested, at)) return TRUE;
    WCHAR marker[PATH_CAP], resume[PATH_CAP], name[80];
    swprintf_s(name, 80, L"reached.%s", at); path(marker, name);
    swprintf_s(name, 80, L"continue.%s", at); path(resume, name);
    HANDLE h = CreateFileW(marker, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) return FALSE;
    DWORD written; BOOL ok = WriteFile(h, "reached", 7, &written, NULL) && written == 7 && FlushFileBuffers(h);
    CloseHandle(h);
    if (!ok) return FALSE;
    ULONGLONG until = GetTickCount64() + 15000;
    while (GetFileAttributesW(resume) == INVALID_FILE_ATTRIBUTES) {
        if (GetTickCount64() >= until) { SetLastError(ERROR_TIMEOUT); return FALSE; }
        Sleep(2);
    }
    return TRUE;
}

int wmain(int argc, WCHAR **argv) {
    if (argc != 4 || !context(argv[2])) return result("rejected", "disposable_context", ERROR_INVALID_PARAMETER, 2);
    BOOL first = !wcscmp(argv[1], L"first"), replace = !wcscmp(argv[1], L"replace");
    if (!wcscmp(argv[1], L"verify")) {
        DWORD expected_n, actual_n;
        if (!read_name(L"verify.bin", new_bytes, &expected_n) || !read_name(L"head.bin", actual, &actual_n))
            return result("unverified", "independent_read", GetLastError(), 3);
        return result(expected_n == actual_n && !memcmp(new_bytes, actual, actual_n) ? "exact" : "mismatch",
                      "independent_read", 0, expected_n == actual_n && !memcmp(new_bytes, actual, actual_n) ? 0 : 3);
    }
    if ((!first && !replace) || (wcscmp(argv[3], L"none") && wcscmp(argv[3], L"before_flush") &&
        wcscmp(argv[3], L"before_api") && wcscmp(argv[3], L"after_api") && wcscmp(argv[3], L"after_readback")))
        return result("rejected", "arguments", ERROR_INVALID_PARAMETER, 2);
    WCHAR lock_path[PATH_CAP]; path(lock_path, L"writer.guard");
    HANDLE lock = CreateFileW(lock_path, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_ALWAYS,
                             FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (lock == INVALID_HANDLE_VALUE) return result("rejected", "writer_lock", GetLastError(), 2);
    BY_HANDLE_FILE_INFORMATION lock_info;
    if (!GetFileInformationByHandle(lock, &lock_info) ||
        lock_info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY) ||
        lock_info.nNumberOfLinks != 1 || lock_info.dwVolumeSerialNumber != volume_serial) {
        CloseHandle(lock); return result("rejected", "writer_lock_shape", ERROR_INVALID_DATA, 2);
    }
    /* OS releases this exclusive handle on termination; the empty file is not
     * a stale-lease claim. No lock-file deletion or timeout-based theft.
     */
    HANDLE stage = INVALID_HANDLE_VALUE, head = INVALID_HANDLE_VALUE;
    int code = 2; DWORD error = 0, old_n = 0, new_n = 0, actual_n = 0;
    const char *state = "rejected", *phase = "precondition";
    stage = open_file(L"stage.bin", GENERIC_READ | GENERIC_WRITE | DELETE, FILE_SHARE_READ | FILE_SHARE_DELETE);
    if (stage == INVALID_HANDLE_VALUE) { phase = "stage_open"; error = GetLastError(); goto done; }
    if (!bytes(stage, new_bytes, &new_n)) { phase = "stage_read"; error = GetLastError(); goto done; }
    if (!new_n) { phase = "stage_read"; error = ERROR_INVALID_DATA; goto done; }
    head = open_file(L"head.bin", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE);
    if (first) {
        if (head != INVALID_HANDLE_VALUE || GetLastError() != ERROR_FILE_NOT_FOUND) {
            phase = "first_requires_absence";
            error = head != INVALID_HANDLE_VALUE ? ERROR_FILE_EXISTS : GetLastError(); goto done;
        }
    } else {
        DWORD expected_n;
        if (head == INVALID_HANDLE_VALUE) { phase = "head_open"; error = GetLastError(); goto done; }
        if (!bytes(head, old_bytes, &old_n) || !read_name(L"expected.bin", actual, &expected_n)) {
            phase = "expected_read"; error = GetLastError(); goto done;
        }
        if (old_n != expected_n || memcmp(old_bytes, actual, old_n)) {
            phase = "expected_head_mismatch"; error = ERROR_REVISION_MISMATCH; goto done;
        }
    }
    phase = "before_flush";
    if (!barrier(argv[3], L"before_flush") || !FlushFileBuffers(stage)) { error = GetLastError(); goto done; }
    phase = "before_api";
    if (!barrier(argv[3], L"before_api")) { error = GetLastError(); goto done; }
    /* On the tested Windows filesystem an open destination can block rename
     * even with DELETE sharing. Release our read handle under writer ownership;
     * external readers are allowed to make the native call fail safely.
     */
    if (head != INVALID_HANDLE_VALUE) { CloseHandle(head); head = INVALID_HANDLE_VALUE; }
    WCHAR source_path[PATH_CAP], target_path[PATH_CAP];
    path(source_path, L"stage.bin"); path(target_path, L"head.bin");
    /* Same directory/volume, no COPY_ALLOWED, no DELETE/rename fallback. */
    api_called = TRUE;
    BOOL moved = MoveFileExW(source_path, target_path, MOVEFILE_WRITE_THROUGH | (replace ? MOVEFILE_REPLACE_EXISTING : 0));
    api_success = moved;
    error = moved ? 0 : GetLastError();
    state = "uncertain"; code = 3; phase = "after_api";
    if (!barrier(argv[3], L"after_api")) { error = GetLastError(); goto done; }
    phase = "readback";
    if (!read_name(L"head.bin", actual, &actual_n)) { readback_error = GetLastError(); goto done; }
    if (moved && actual_n == new_n && !memcmp(actual, new_bytes, new_n)) {
        state = "published_verified"; code = 0;
    } else if (!moved && replace && actual_n == old_n && !memcmp(actual, old_bytes, old_n)) {
        state = "failed_preserved"; code = 2;
    }
    if (!barrier(argv[3], L"after_readback")) { state = "uncertain"; code = 3; error = GetLastError(); }
done:
    if (head != INVALID_HANDLE_VALUE) CloseHandle(head);
    if (stage != INVALID_HANDLE_VALUE) CloseHandle(stage);
    /* Report under ownership, including exact native error, before unlocking. */
    result(state, phase, error, code);
    CloseHandle(lock);
    return code;
}
