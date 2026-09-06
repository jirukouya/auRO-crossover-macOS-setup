/* Portable detector for the wow64_NtUserGetRawInputDeviceList() overflow.
 *
 * GetRawInputDeviceList(buf, &count, size) must fill exactly `ret` entries and
 * leave the rest of the caller's buffer untouched. Wine's WoW64 thunk converts
 * `*count` entries instead -- the capacity the caller passed in -- so every
 * entry past the real device count is copied out of an uninitialised temp block
 * into the caller's buffer.
 */
#include <windows.h>
#include <stdio.h>

#define CAP 240

int main(void)
{
    RAWINPUTDEVICELIST buf[CAP];
    UINT count, ret, i, dirty = 0, first_dirty = 0;

    count = 0;
    ret = GetRawInputDeviceList(NULL, &count, sizeof(RAWINPUTDEVICELIST));
    printf("query   : ret=%d  devices=%u\n", (int)ret, count);

    memset(buf, 0xCC, sizeof(buf));
    count = CAP;
    ret = GetRawInputDeviceList(buf, &count, sizeof(RAWINPUTDEVICELIST));
    printf("fill    : ret=%d  count_out=%u  capacity_in=%u\n", (int)ret, count, CAP);
    if (ret == (UINT)-1) { printf("call failed, cannot judge\n"); return 2; }

    for (i = ret; i < CAP; i++)
    {
        if (buf[i].hDevice != (HANDLE)(ULONG_PTR)0xCCCCCCCC || buf[i].dwType != 0xCCCCCCCC)
        {
            if (!dirty) first_dirty = i;
            dirty++;
        }
    }
    printf("devices returned : %u\n", ret);
    printf("entries clobbered past the returned count : %u\n", dirty);
    if (dirty) printf("first clobbered index : %u\n", first_dirty);
    printf("AFFECTED=%s\n", dirty ? "yes" : "no");
    return dirty ? 1 : 0;
}
