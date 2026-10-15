package com.sbxmod.paletteMaker
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.utils.Dictionary;

	/**
	 * Shell match runtime: apply costume fxGroups (HSBC + color) on projectiles /
	 * stage-attached effect MCs and linkage-gated fighter display children.
	 *
	 * INCLUDE: AFTER_ATTACH_EFFECT*, StageRef/StageEffectsRef children with owner uid,
	 * owned Projectiles/Items, shallow fighter-tree children named in fxGroups.
	 * EXCLUDE: player.MC root, stance itself, shared dust/land/jump stage ids, body/form ids.
	 */
	public class CostumeFxPaletteRuntime
	{
		/** Fighter FX re-walk at least this often even when the signature holds. */
		private static const FIGHTER_SAFETY_FRAMES:int = 30;
		private static var s_host:*;
		private static var s_ticking:Boolean = false;
		private static var s_loggedKameDump:Boolean = false;
		/** player -> root numChildren at the last fighter FX walk */
		private static var s_fighterRootKids:Dictionary = new Dictionary(true);
		/** player -> Stance numChildren at the last fighter FX walk */
		private static var s_fighterStanceKids:Dictionary = new Dictionary(true);
		/** player -> Stance clip seen at the last fighter FX walk */
		private static var s_fighterStance:Dictionary = new Dictionary(true);
		/** StageRef / StageEffectsRef layer -> numChildren at the last walk */
		private static var s_layerKids:Dictionary = new Dictionary(true);
		private static var s_uidMap:Dictionary = null;
		private static var s_uidPlayers:Array = [];
		private static var s_uidCostumes:Array = [];
		private static var s_forceFighterApply:Boolean = false;
		private static var s_applied:Dictionary = new Dictionary(true);
		/** owner -> full costume object (or null) */
		private static var s_costumeByOwner:Dictionary = new Dictionary(true);
		private static var s_loggedMatch:Boolean = false;
		private static var s_loggedAttach:Boolean = false;
		private static var s_loggedTree:Boolean = false;
		private static var s_loggedBakedExclude:Boolean = false;
		private static var s_lastMatchBakedMc:String = "";
		private static var s_bakedMcLogCount:int = 0;
		private static var s_attachMissLogged:Object = {};
		private static var s_stageMissLogged:Object = {};
		private static var s_tickCount:int = 0;
		/**
		 * Studio RE harvest callback: function(linkage:String):void.
		 * Invoked on AFTER_ATTACH_EFFECT* even when costume has no FX adjust yet.
		 */
		public static var studioAttachHarvest:Function = null;

		public static function boot(host:*):void
		{
			s_host = host;
			if (!host)
			{
				return;
			};
			try
			{
				host.addHook("MATCH_START", onMatchStart);
				host.addHook("MATCH_END", onMatchEnd);
				host.addHook("AFTER_PROJECTILE_SPAWN", onAfterProjectileSpawn);
				host.addHook("AFTER_ATTACH_EFFECT", onAfterAttachEffect);
				host.addHook("AFTER_ATTACH_EFFECT_OVERLAY", onAfterAttachEffect);
			}
			catch (err:*)
			{
				trace("[palette_maker] CostumeFxPaletteRuntime boot failed: " + err);
			};
		}

		public static function shutdown():void
		{
			stopTick();
			s_applied = new Dictionary(true);
			s_costumeByOwner = new Dictionary(true);
			if (s_host)
			{
				try
				{
					s_host["removeHook"]("MATCH_START", onMatchStart);
					s_host["removeHook"]("MATCH_END", onMatchEnd);
					s_host["removeHook"]("AFTER_PROJECTILE_SPAWN", onAfterProjectileSpawn);
					s_host["removeHook"]("AFTER_ATTACH_EFFECT", onAfterAttachEffect);
					s_host["removeHook"]("AFTER_ATTACH_EFFECT_OVERLAY", onAfterAttachEffect);
				}
				catch (err:*)
				{
				};
			};
			s_host = null;
		}

		private static function onMatchStart(ctx:Object):void
		{
			resetMatchState();
			s_loggedKameDump = false;
			startTick();
			s_forceFighterApply = true;
			applyAllLive();
			logMatchFxScan();
		}

		private static function onMatchEnd(ctx:Object):void
		{
			stopTick();
			resetMatchState();
		}

		private static function resetMatchState():void
		{
			s_applied = new Dictionary(true);
			s_costumeByOwner = new Dictionary(true);
			s_fighterRootKids = new Dictionary(true);
			s_fighterStanceKids = new Dictionary(true);
			s_fighterStance = new Dictionary(true);
			s_layerKids = new Dictionary(true);
			s_uidMap = null;
			s_uidPlayers = [];
			s_uidCostumes = [];
			FxRecolorUtils.clearProjectileFxAliasCache();
			s_forceFighterApply = false;
			s_loggedMatch = false;
			s_loggedAttach = false;
			s_loggedTree = false;
			s_loggedBakedExclude = false;
			s_lastMatchBakedMc = "";
			s_bakedMcLogCount = 0;
			s_attachMissLogged = {};
			s_stageMissLogged = {};
			s_tickCount = 0;
		}

		private static function onAfterProjectileSpawn(ctx:Object):void
		{
			var proj:*;
			var owner:*;
			var costume:Object;
			var mc:DisplayObject;
			var group:Object;
			var linkage:String;
			var aliases:Object;
			var statsName:String;
			var swapResult:Object;
			if (!ctx)
			{
				return;
			};
			s_forceFighterApply = true;
			proj = ctx.projectile;
			if (!proj)
			{
				return;
			};
			owner = resolveOwner(proj);
			mc = resolveMc(proj);
			linkage = resolveFxLinkage(mc, proj, ctx.proj);
			if ((!linkage || linkage.length == 0) && proj)
			{
				try
				{
					if (proj.LinkageID)
					{
						linkage = String(proj.LinkageID).toLowerCase();
					};
				}
				catch (lidErr:*)
				{
				};
			};
			if (studioAttachHarvest != null && linkage)
			{
				try
				{
					studioAttachHarvest(linkage);
				}
				catch (harvestErr:*)
				{
				};
			};
			costume = costumeFromOwner(owner);
			if (!FxRecolorUtils.costumeHasFxAdjust(costume))
			{
				return;
			};
			if (!mc)
			{
				return;
			};
			statsName = resolveCostumeName(owner);
			aliases = statsName ? FxRecolorUtils.buildProjectileFxAliasMap(statsName) : null;
			group = FxRecolorUtils.findFxGroupForLinkage(costume, linkage, aliases);
			if (!group && ctx.proj)
			{
				group = FxRecolorUtils.findFxGroupForLinkage(costume, String(ctx.proj), aliases);
			};
			if (!group)
			{
				return;
			};
			swapResult = FxRecolorUtils.applyFxSwapOrFilters(mc, costume, group, 8, 200);
			s_applied[proj] = true;
			matchDebug("proj FX link=" + linkage
				+ " group=" + (group.name || group.id)
				+ " painted=" + int(swapResult.painted)
				+ " fallbackFilters=" + int(swapResult.fallbackFilters)
				+ " owner=" + resolveCostumeName(owner));
		}

		private static function onAfterAttachEffect(ctx:Object):void
		{
			var character:*;
			var effect:DisplayObject;
			var costume:Object;
			var id:*;
			var group:Object;
			var linkage:String;
			var swapResult:Object;
			if (!ctx)
			{
				return;
			};
			s_forceFighterApply = true;
			id = ctx.id;
			if (FxRecolorUtils.isSharedStageEffectId(id))
			{
				return;
			};
			character = ctx.character;
			effect = ctx.effect as DisplayObject;
			if (!effect)
			{
				return;
			};
			if (effect === resolveMc(character))
			{
				return;
			};
			linkage = resolveFxLinkage(effect, null, id);
			if (studioAttachHarvest != null && linkage)
			{
				try
				{
					studioAttachHarvest(linkage);
				}
				catch (harvestErr:*)
				{
				};
			};
			costume = costumeFromOwner(character);
			if (!FxRecolorUtils.costumeHasFxAdjust(costume))
			{
				return;
			};
			group = FxRecolorUtils.findFxGroupForLinkage(costume, linkage,
				FxRecolorUtils.buildProjectileFxAliasMap(resolveCostumeName(character)));
			if (!group)
			{
				if (linkage && !s_attachMissLogged[linkage])
				{
					s_attachMissLogged[linkage] = true;
					matchDebug("attach miss id=" + linkage
						+ " name=" + (effect && effect.name ? effect.name : "?")
						+ " class=" + FxRecolorUtils.effectIdToLower(effect)
						+ " owner=" + resolveCostumeName(character));
				};
				return;
			};
			swapResult = FxRecolorUtils.applyFxSwapOrFilters(effect, costume, group, 8, 200);
			s_applied[effect] = true;
			if (!s_attachMissLogged["hit:" + linkage])
			{
				s_attachMissLogged["hit:" + linkage] = true;
				matchDebug("attach FX id=" + linkage
					+ " group=" + (group.name || group.id)
					+ " painted=" + int(swapResult.painted)
					+ " fallbackFilters=" + int(swapResult.fallbackFilters)
					+ " class=" + FxRecolorUtils.effectIdToLower(effect)
					+ " owner=" + resolveCostumeName(character));
			};
		}

		private static function startTick():void
		{
			var root:*;
			if (s_ticking)
			{
				return;
			};
			try
			{
				root = Ssf2.Main.Root;
				if (root)
				{
					root.addEventListener(Event.ENTER_FRAME, onTick, false, 0, true);
					s_ticking = true;
				};
			}
			catch (err:*)
			{
			};
		}

		private static function stopTick():void
		{
			var root:*;
			if (!s_ticking)
			{
				return;
			};
			try
			{
				root = Ssf2.Main.Root;
				if (root)
				{
					root.removeEventListener(Event.ENTER_FRAME, onTick);
				};
			}
			catch (err:*)
			{
			};
			s_ticking = false;
		}

		private static function onTick(e:Event):void
		{
			try
			{
				tickLive(e);
			}
			catch (err:*)
			{
				PaletteGuard.fail("fx recolor tick", err);
			};
		}

		private static function tickLive(e:Event):void
		{
			s_tickCount++;
			applyAllLive();
		}

		private static function applyAllLive():void
		{
			var stageData:*;
			var players:*;
			var i:int;
			var p:*;
			var uidMap:Dictionary;
			var forceLayers:Boolean;
			try
			{
				stageData = Ssf2.GameController.stageData;
			}
			catch (err:*)
			{
				return;
			};
			if (!stageData)
			{
				return;
			};
			if (!anyPlayerHasFx(stageData))
			{
				return;
			};
			forceLayers = s_forceFighterApply || (s_tickCount % FIGHTER_SAFETY_FRAMES) == 0;
			if (uidOwnersChanged(stageData))
			{
				s_uidMap = buildUidOwnerMap(stageData);
				forceLayers = true;
			};
			uidMap = s_uidMap;
			applyOwnedList(tryGetList(stageData, "Projectiles"));
			applyOwnedList(tryGetList(stageData, "Items"));
			applyStageEffectLayer(tryGetDisplayContainer(stageData, "StageRef"), uidMap, forceLayers);
			applyStageEffectLayer(tryGetDisplayContainer(stageData, "StageEffectsRef"), uidMap, forceLayers);
			try
			{
				players = stageData.Players;
				if (players)
				{
					i = 0;
					while (i < players.length)
					{
						p = players[i];
						applyPlayerEffects(p);
						if (fighterNeedsApply(p))
						{
							applyFighterFxChildren(p);
						};
						i++;
					};
				};
			}
			catch (fxErr:*)
			{
			};
			s_forceFighterApply = false;
		}

		/**
		 * True when the fighter display tree may hold new, untinted children: Stance clip
		 * or a root / Stance child count changed since the last walk.
		 * Hooks set s_forceFighterApply; FIGHTER_SAFETY_FRAMES re-walks regardless.
		 */
		private static function fighterNeedsApply(player:*):Boolean
		{
			var root:MovieClip;
			var stance:MovieClip;
			var rootKids:int;
			var stanceKids:int;
			try
			{
				root = resolveMc(player) as MovieClip;
				stance = player.Stance as MovieClip;
			}
			catch (err:*)
			{
			};
			rootKids = root ? root.numChildren : -1;
			stanceKids = stance ? stance.numChildren : -1;
			if (!s_forceFighterApply
				&& (s_tickCount % FIGHTER_SAFETY_FRAMES) != 0
				&& s_fighterStance[player] === stance
				&& s_fighterRootKids[player] === rootKids
				&& s_fighterStanceKids[player] === stanceKids)
			{
				return false;
			};
			s_fighterRootKids[player] = rootKids;
			s_fighterStanceKids[player] = stanceKids;
			s_fighterStance[player] = stance;
			return true;
		}

		/** True when the player list or a player's costume changed since the last uid map build. */
		private static function uidOwnersChanged(stageData:*):Boolean
		{
			var players:*;
			var i:int;
			var n:int;
			var p:*;
			var costume:Object;
			var changed:Boolean;
			try
			{
				players = stageData.Players;
			}
			catch (err:*)
			{
				players = null;
			};
			n = players ? int(players.length) : 0;
			changed = s_uidMap == null || n != s_uidPlayers.length;
			i = 0;
			while (i < n)
			{
				p = players[i];
				costume = costumeFromOwner(p);
				if (s_uidPlayers[i] !== p || s_uidCostumes[i] !== costume)
				{
					if (i < s_uidCostumes.length && s_uidCostumes[i] !== costume)
					{
						FxRecolorUtils.clearProjectileFxAliasCache();
					};
					s_uidPlayers[i] = p;
					s_uidCostumes[i] = costume;
					changed = true;
				};
				i++;
			};
			s_uidPlayers.length = n;
			s_uidCostumes.length = n;
			return changed;
		}

		private static function tryGetList(stageData:*, prop:String):*
		{
			var list:*;
			if (!stageData || !prop)
			{
				return null;
			};
			try
			{
				list = stageData[prop];
				return list;
			}
			catch (err:*)
			{
			};
			return null;
		}

		private static function tryGetDisplayContainer(stageData:*, prop:String):DisplayObjectContainer
		{
			var obj:*;
			if (!stageData || !prop)
			{
				return null;
			};
			try
			{
				obj = stageData[prop];
				if (obj is DisplayObjectContainer)
				{
					return obj as DisplayObjectContainer;
				};
			}
			catch (err:*)
			{
			};
			return null;
		}

		private static function anyPlayerHasFx(stageData:*):Boolean
		{
			var players:*;
			var i:int;
			var p:*;
			try
			{
				players = stageData.Players;
				if (!players)
				{
					return false;
				};
				i = 0;
				while (i < players.length)
				{
					p = players[i];
					if (FxRecolorUtils.costumeHasFxAdjust(costumeFromOwner(p)))
					{
						return true;
					};
					i++;
				};
			}
			catch (err:*)
			{
			};
			return false;
		}

		private static function buildUidOwnerMap(stageData:*):Dictionary
		{
			var map:Dictionary;
			var players:*;
			var i:int;
			var p:*;
			var uid:int;
			map = new Dictionary();
			try
			{
				players = stageData.Players;
				if (!players)
				{
					return map;
				};
				i = 0;
				while (i < players.length)
				{
					p = players[i];
					if (p && FxRecolorUtils.costumeHasFxAdjust(costumeFromOwner(p)))
					{
						uid = resolveUid(p);
						if (uid != 0)
						{
							map[uid] = p;
						};
					};
					i++;
				};
			}
			catch (err:*)
			{
			};
			return map;
		}

		private static function resolveUid(owner:*):int
		{
			try
			{
				return int(owner.UID);
			}
			catch (err:*)
			{
			};
			try
			{
				return int(owner["m_uid"]);
			}
			catch (err2:*)
			{
			};
			return 0;
		}

		private static function applyOwnedList(list:*):void
		{
			var i:int;
			var n:int;
			var obj:*;
			var owner:*;
			var costume:Object;
			var mc:DisplayObject;
			if (!list)
			{
				return;
			};
			try
			{
				n = int(list.length);
			}
			catch (lenErr:*)
			{
				return;
			};
			i = 0;
			while (i < n)
			{
				try
				{
					obj = list[i];
					if (!obj || s_applied[obj])
					{
						i++;
						continue;
					};
					owner = resolveOwner(obj);
					costume = costumeFromOwner(owner);
					if (!FxRecolorUtils.costumeHasFxAdjust(costume))
					{
						i++;
						continue;
					};
					mc = resolveMc(obj);
					if (mc)
					{
						applyFxForObject(mc, costume, obj, null);
						s_applied[obj] = true;
					};
				}
				catch (itemErr:*)
				{
				};
				i++;
			};
		}

		private static function applyStageEffectLayer(layer:DisplayObjectContainer, uidMap:Dictionary, force:Boolean):void
		{
			var i:int;
			var n:int;
			var child:DisplayObject;
			var uid:int;
			var owner:*;
			var costume:Object;
			var last:*;
			if (!layer || !uidMap)
			{
				return;
			};
			try
			{
				n = layer.numChildren;
			}
			catch (err:*)
			{
				return;
			};
			last = s_layerKids[layer];
			s_layerKids[layer] = n;
			if (!force && last !== undefined && n <= int(last))
			{
				return;
			};
			i = 0;
			while (i < n)
			{
				try
				{
					child = layer.getChildAt(i);
					if (!child || s_applied[child])
					{
						i++;
						continue;
					};
					uid = 0;
					try
					{
						uid = int(child["uid"]);
					}
					catch (uidErr:*)
					{
						uid = 0;
					};
					if (uid == 0 || uidMap[uid] == undefined)
					{
						i++;
						continue;
					};
					owner = uidMap[uid];
					// Never tint the fighter display object itself.
					if (owner && child === resolveMc(owner))
					{
						i++;
						continue;
					};
					if (FxRecolorUtils.isSharedStageEffectId(child.name))
					{
						i++;
						continue;
					};
					costume = costumeFromOwner(owner);
					if (!FxRecolorUtils.costumeHasFxAdjust(costume))
					{
						i++;
						continue;
					};
					applyFxForObject(child, costume, null, child.name);
					s_applied[child] = true;
				}
				catch (childErr:*)
				{
				};
				i++;
			};
		}

		private static function applyPlayerEffects(player:*):void
		{
			var costume:Object;
			var list:*;
			var i:int;
			var n:int;
			var obj:*;
			var mc:DisplayObject;
			if (!player)
			{
				return;
			};
			try
			{
				list = player["effects"];
			}
			catch (effErr:*)
			{
				return;
			};
			if (!(list is Array))
			{
				return;
			};
			costume = costumeFromOwner(player);
			if (!FxRecolorUtils.costumeHasFxAdjust(costume))
			{
				return;
			};
			try
			{
				n = int(list.length);
			}
			catch (lenErr:*)
			{
				return;
			};
			i = 0;
			while (i < n)
			{
				try
				{
					obj = list[i];
					if (!obj || s_applied[obj])
					{
						i++;
						continue;
					};
					mc = resolveMc(obj);
					if (mc)
					{
						applyFxForObject(mc, costume, obj, null);
						s_applied[obj] = true;
					};
				}
				catch (itemErr:*)
				{
				};
				i++;
			};
		}

		/**
		 * Linkage-gated shallow tint + whole-MC baked FX (tint frame, undo body pixels).
		 * Never filters player.MC root.
		 */
		private static function applyFighterFxChildren(player:*):void
		{
			var costume:Object;
			var root:DisplayObject;
			var statsName:String;
			var aliases:Object;
			var tinted:int;
			var baked:int;
			var linkageTinted:Dictionary;
			if (!player)
			{
				return;
			};
			costume = costumeFromOwner(player);
			if (!FxRecolorUtils.costumeHasFxAdjust(costume))
			{
				return;
			};
			root = resolveMc(player);
			if (!root)
			{
				return;
			};
			statsName = resolveCostumeName(player);
			aliases = statsName ? FxRecolorUtils.buildProjectileFxAliasMap(statsName) : null;
			linkageTinted = new Dictionary(true);
			tinted = FxRecolorUtils.applyFxGroupsToFighterDisplayTree(
				root, costume, aliases, 8, 250, statsName, linkageTinted);
			baked = FxRecolorUtils.applyFxGroupsToFighterBakedMc(
				root, costume, linkageTinted, 10, 500, statsName);
			if (tinted > 0 && !s_loggedTree)
			{
				s_loggedTree = true;
				matchDebug("fighter-tree FX tinted=" + tinted
					+ " owner=" + (statsName || "?"));
			};
			if (FxRecolorUtils.lastFxSwapName
				&& s_bakedMcLogCount < 6
				&& (FxRecolorUtils.lastFxSwapName != s_lastMatchBakedMc
					|| FxRecolorUtils.lastFxSwapBitmaps > 0 && !s_loggedBakedExclude))
			{
				if (FxRecolorUtils.lastFxSwapBitmaps > 0)
				{
					s_loggedBakedExclude = true;
				};
				s_lastMatchBakedMc = FxRecolorUtils.lastFxSwapName;
				s_bakedMcLogCount++;
				matchDebug("fx-swap mc=" + (FxRecolorUtils.lastFxSwapName || "?")
					+ " painted=" + FxRecolorUtils.lastFxSwapBitmaps
					+ " visitedBitmaps=" + FxRecolorUtils.lastFxSwapVisitedBitmaps
					+ " blockColors=" + FxRecolorUtils.lastFxSwapBlockColors
					+ " owner=" + (statsName || "?"));
				maybeLogKameDump(FxRecolorUtils.lastFxSwapName,
					FxRecolorUtils.lastFxStanceChildDump);
			}
			else if (FxRecolorUtils.lastFxSwapSkipReason
				&& s_bakedMcLogCount < 6
				&& FxRecolorUtils.lastFxSwapSkipReason != s_lastMatchBakedMc)
			{
				s_lastMatchBakedMc = FxRecolorUtils.lastFxSwapSkipReason;
				s_bakedMcLogCount++;
				matchDebug("fx-swap skip=" + FxRecolorUtils.lastFxSwapSkipReason
					+ " owner=" + (statsName || "?"));
			};
		}

		/** One-shot dump when neutralspecial_* (or other special) is the baked FX target. */
		private static function maybeLogKameDump(mcName:String, childDump:String):void
		{
			var low:String;
			if (s_loggedKameDump || !mcName)
			{
				return;
			};
			low = mcName.toLowerCase();
			if (low.indexOf("special") < 0 && low.indexOf("smash") < 0)
			{
				return;
			};
			s_loggedKameDump = true;
			matchDebug("kame-dump mc=" + mcName
				+ " painted=" + FxRecolorUtils.lastFxSwapBitmaps
				+ " visitedBitmaps=" + FxRecolorUtils.lastFxSwapVisitedBitmaps
				+ " blockColors=" + FxRecolorUtils.lastFxSwapBlockColors
				+ " kids=" + (childDump || "?"));
		}

		private static function applyFxForObject(mc:DisplayObject, costume:Object, obj:*, fallbackId:*):void
		{
			var group:Object;
			var linkage:String;
			var aliases:Object;
			var statsName:String;
			if (!mc || !costume)
			{
				return;
			};
			linkage = resolveFxLinkage(mc, obj, fallbackId);
			if ((!linkage || linkage.length == 0) && obj)
			{
				try
				{
					if (obj.LinkageID)
					{
						linkage = String(obj.LinkageID).toLowerCase();
					};
				}
				catch (lidErr:*)
				{
				};
			};
			statsName = null;
			try
			{
				statsName = costume.statsName ? String(costume.statsName)
					: (costume.character ? String(costume.character) : null);
			}
			catch (snErr:*)
			{
				statsName = null;
			};
			aliases = statsName ? FxRecolorUtils.buildProjectileFxAliasMap(statsName) : null;
			group = FxRecolorUtils.findFxGroupForLinkage(costume, linkage, aliases);
			if (!group && fallbackId != null)
			{
				group = FxRecolorUtils.findFxGroupForLinkage(costume, String(fallbackId), aliases);
			};
			if (!group)
			{
				return;
			};
			// Bitmap palette swap first; filter fallback for vector attach/proj MCs.
			FxRecolorUtils.applyFxSwapOrFilters(mc, costume, group, 8, 200);
		}

		private static function resolveFxLinkage(mc:DisplayObject, obj:*, fallbackId:*):String
		{
			var s:String;
			s = FxRecolorUtils.resolveDisplayFxLinkage(mc, fallbackId);
			if (s)
			{
				return s;
			};
			if (obj)
			{
				try
				{
					if (obj.LinkageID)
					{
						return String(obj.LinkageID).toLowerCase();
					};
				}
				catch (err:*)
				{
				};
				try
				{
					if (obj.linkage_id)
					{
						return String(obj.linkage_id).toLowerCase();
					};
				}
				catch (err2:*)
				{
				};
			};
			return FxRecolorUtils.effectIdToLower(fallbackId);
		}

		private static function costumeFromOwner(owner:*):Object
		{
			var cached:*;
			var data:Object;
			var name:String;
			var costumeId:int;
			if (!owner)
			{
				return null;
			};
			cached = s_costumeByOwner[owner];
			if (cached !== undefined)
			{
				return cached as Object;
			};
			name = resolveCostumeName(owner);
			costumeId = resolveCostumeId(owner);
			if (name)
			{
				try
				{
					data = Ssf2.ResourceManager.getCostume(name, null, costumeId) as Object;
					if (data)
					{
						s_costumeByOwner[owner] = data;
						return data;
					};
				}
				catch (rmErr:*)
				{
				};
			};
			s_costumeByOwner[owner] = null;
			return null;
		}

		private static function resolveCostumeName(owner:*):String
		{
			try
			{
				if (owner.CostumeName)
				{
					return String(owner.CostumeName);
				};
			}
			catch (err:*)
			{
			};
			try
			{
				if (owner.StatsName)
				{
					return String(owner.StatsName);
				};
			}
			catch (err2:*)
			{
			};
			return null;
		}

		private static function resolveCostumeId(owner:*):int
		{
			try
			{
				return int(owner.CostumeID);
			}
			catch (err:*)
			{
			};
			try
			{
				return int(owner["m_costume"]);
			}
			catch (err2:*)
			{
			};
			return -1;
		}

		private static function logMatchFxScan():void
		{
			var stageData:*;
			var players:*;
			var i:int;
			var p:*;
			var costume:Object;
			var parts:Array;
			if (s_loggedMatch)
			{
				return;
			};
			s_loggedMatch = true;
			parts = [];
			try
			{
				stageData = Ssf2.GameController.stageData;
				players = stageData ? stageData.Players : null;
				if (players)
				{
					i = 0;
					while (i < players.length)
					{
						p = players[i];
						costume = costumeFromOwner(p);
						parts.push("p" + i
							+ " name=" + resolveCostumeName(p)
							+ " id=" + resolveCostumeId(p)
							+ " uid=" + resolveUid(p)
							+ " groups=" + (costume && costume.fxGroups is Array ? (costume.fxGroups as Array).length : 0)
							+ " hasFx=" + FxRecolorUtils.costumeHasFxAdjust(costume));
						i++;
					};
				};
			}
			catch (err:*)
			{
				parts.push("scanErr=" + err);
			};
			matchDebug("MATCH FX scan " + parts.join(" | "));
		}

		/** One game.log line when the Palette Maker Debug logging setting is on. */
		private static function matchDebug(msg:String):void
		{
			if (!PaletteMakerMenu.isDebugLogging())
			{
				return;
			};
			Ssf2.gameLog("[palette_maker] match " + msg);
		}

		private static function resolveOwner(obj:*):*
		{
			var owner:*;
			if (!obj)
			{
				return null;
			};
			try
			{
				owner = obj.Owner != null ? obj.Owner : obj["m_owner"];
				if (owner)
				{
					return owner;
				};
			}
			catch (o1:*)
			{
			};
			try
			{
				return obj.getOwner();
			}
			catch (o2:*)
			{
			};
			return null;
		}

		private static function resolveMc(obj:*):DisplayObject
		{
			if (!obj)
			{
				return null;
			};
			if (obj is DisplayObject)
			{
				return obj as DisplayObject;
			};
			try
			{
				if (obj.MC is DisplayObject)
				{
					return obj.MC as DisplayObject;
				};
			}
			catch (err:*)
			{
			};
			try
			{
				if (obj.mc is DisplayObject)
				{
					return obj.mc as DisplayObject;
				};
			}
			catch (err2:*)
			{
			};
			return null;
		}
	}
}
