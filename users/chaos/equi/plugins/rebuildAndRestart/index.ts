import { ApplicationCommandInputType } from "@api/Commands";
import definePlugin from "@utils/types";

export default definePlugin({
    name: "Rebuild and restart",
    description: "Adds utils for rebuild and restarting the client",
    authors: [{ name: "chaos_the_chaotic", id: 799267390827003916n }],
    commands: [
        {
            name: "Rebuild and restart (rbars)",
            description: "Rebuilds the client",
            inputType: ApplicationCommandInputType.BUILT_IN,
            execute(_, __) {
                VencordNative.updater.rebuild()
                location.reload();
            },
        },
        {
            name: "Restart",
            description: "Restarts the client",
            inputType: ApplicationCommandInputType.BUILT_IN,
            execute(_, __) {
                location.reload();
            },
        },
        {
            name: "Rebuild",
            description: "Rebuilds Vencord",
            inputType: ApplicationCommandInputType.BUILT_IN,
            execute(_, __) {
                VencordNative.updater.rebuild()
            },
        }
    ],
    toolboxActions: {
        "Rebuild and restart"() {
            VencordNative.updater.rebuild()
            location.reload();
        },
        "Rebuild"(){
            VencordNative.updater.rebuild()
        },
        "Restart"(){
            location.reload();
        },
    }
});
