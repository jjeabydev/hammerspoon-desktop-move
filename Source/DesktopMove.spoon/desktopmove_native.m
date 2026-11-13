// Based on Hammerspoon PR #3889 by franzbu (Hammerspoon, MIT license).
// Use the current WindowServer operation instead of the obsolete Spaces API.
#import <Cocoa/Cocoa.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#import <stdint.h>
#import <string.h>
#include <lua.h>
#include <lauxlib.h>

typedef int64_t (*PerformOperation)(void *operation);
static PerformOperation performOperation;

@interface NSObject (DesktopMoveOperation)
- (instancetype)initWithWindows:(NSArray *)windows spaceID:(uint64_t)spaceID;
@end

static void *findOperation(void) {
    const char *name = "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperationP47SLSAsynchronousBridgedWindowManagementOperation";
    dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY | RTLD_GLOBAL);
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *path = _dyld_get_image_name(i);
        if (!path || !strstr(path, "/SkyLight.framework/")) continue;
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (header->magic != MH_MAGIC_64) continue;
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        const struct segment_command_64 *linkedit = NULL;
        const struct symtab_command *symtab = NULL;
        const uint8_t *cursor = (const uint8_t *)header + sizeof(*header);
        for (uint32_t j = 0; j < header->ncmds; j++) {
            const struct load_command *command = (const struct load_command *)cursor;
            if (command->cmd == LC_SEGMENT_64) {
                const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
                if (strncmp(segment->segname, SEG_LINKEDIT, sizeof(segment->segname)) == 0) linkedit = segment;
            } else if (command->cmd == LC_SYMTAB) {
                symtab = (const struct symtab_command *)command;
            }
            cursor += command->cmdsize;
        }
        if (!linkedit || !symtab) continue;
        uintptr_t base = (uintptr_t)slide + linkedit->vmaddr - linkedit->fileoff;
        const char *strings = (const char *)(base + symtab->stroff);
        const struct nlist_64 *symbols = (const struct nlist_64 *)(base + symtab->symoff);
        for (uint32_t j = 0; j < symtab->nsyms; j++) {
            uint32_t offset = symbols[j].n_un.n_strx;
            if (offset && offset < symtab->strsize && strcmp(strings + offset, name) == 0) {
                return (void *)((uintptr_t)slide + symbols[j].n_value);
            }
        }
    }
    return NULL;
}

static int nativeAvailable(lua_State *L) {
    Class cls = NSClassFromString(@"SLSBridgedMoveWindowsToManagedSpaceOperation");
    lua_pushboolean(L, performOperation && cls && [cls instancesRespondToSelector:@selector(initWithWindows:spaceID:)]);
    return 1;
}

static int nativeMove(lua_State *L) {
    lua_Integer window = luaL_checkinteger(L, 1);
    lua_Integer space = luaL_checkinteger(L, 2);
    if (window <= 0 || space <= 0) return luaL_error(L, "window and space IDs must be positive");
    Class cls = NSClassFromString(@"SLSBridgedMoveWindowsToManagedSpaceOperation");
    if (!performOperation || !cls || ![cls instancesRespondToSelector:@selector(initWithWindows:spaceID:)]) {
        lua_pushnil(L);
        lua_pushliteral(L, "current WindowServer move operation is unavailable");
        return 2;
    }
    @try {
        id operation = [[cls alloc] initWithWindows:@[@(window)] spaceID:(uint64_t)space];
        if (!operation) {
            lua_pushnil(L);
            lua_pushliteral(L, "unable to create WindowServer move operation");
            return 2;
        }
        performOperation((__bridge void *)operation);
        lua_pushboolean(L, 1);
        return 1;
    } @catch (NSException *exception) {
        lua_pushnil(L);
        lua_pushstring(L, exception.reason.UTF8String);
        return 2;
    }
}

int luaopen_desktopmove_native(lua_State *L) {
    performOperation = (PerformOperation)findOperation();
    static const luaL_Reg functions[] = {
        {"available", nativeAvailable}, {"move", nativeMove}, {NULL, NULL}
    };
    luaL_newlib(L, functions);
    return 1;
}
