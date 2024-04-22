import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import List "mo:base/List";
import Array "mo:base/Array";
import Error "mo:base/Error";

module {

    type canister_id = Principal;
    type canister_settings = { controllers : [Principal] };

    let ic00 = actor "aaaaa-aa" : actor {
        create_canister : () -> async { canister_id : Principal };
        stop_canister : Principal -> async ();
        delete_canister : Principal -> async ();
        canister_status : { canister_id : Principal } -> async {
            settings : { controllers : [Principal] };
        };
        deposit_cycles : Principal -> async ();
        provisional_top_up_canister : (Principal, Nat) -> ();
        update_settings : {
            canister_id : Principal;
            settings : canister_settings;
        } -> ();
    };

    public func update_settings_add_controller(cid : Principal, controller : Principal) : async () {
        var result = await ic00.canister_status({ canister_id = cid });
        var settings = result.settings;
        var controllers : [Principal] = settings.controllers;
        var controllerList = List.append(List.fromArray([controller]), List.fromArray(controllers));
        ic00.update_settings({
            canister_id = cid;
            settings = { controllers = List.toArray(controllerList) };
        });
    };

    public func update_settings_identity_controllers(cid : Principal, addControllers : [Principal]) : async () {
        var result = await ic00.canister_status({ canister_id = cid });
        var settings = result.settings;
        var controllers : [Principal] = settings.controllers;
        var controllerList = Array.append(addControllers, controllers);
        ic00.update_settings({
            canister_id = cid;
            settings = { controllers = controllerList };
        });
    };

    public func set_canister_controllers(cid : Principal, controllers : [Principal]) : async () {
        ic00.update_settings({
            canister_id = cid;
            settings = { controllers = controllers };
        });
    };


    public func stop_canister(cid : Principal) : async () {
        ignore ic00.stop_canister(cid);
    };

    public func delete_canister(cid : Principal) : async () {
        ignore ic00.delete_canister(cid);
    };

    public func create_canister() : async Principal {
        return (await ic00.create_canister()).canister_id;
    };

    public func canister_status(cid : Principal) : async {
        settings : { controllers : [Principal] };
    } {
        return await ic00.canister_status({ canister_id = cid });
    };

    public func getControllers(cid : Principal) : async [Principal] {
        let status = await ic00.canister_status({ canister_id = cid });
        return status.settings.controllers;
    };

    public func isController(caller : Principal, principal : Principal) : async Bool {
        var controllerLists = await getControllers(caller);
        return switch (Array.find<Principal>(controllerLists, func(a : Principal) : Bool { return Principal.equal(principal, a) })) {
            case (?data) { return true };
            case (_) { throw Error.reject("permission_denied") };
        };
    };
};
