package com.mcleodgaming.ssf2.menus
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.api.SSF2API;
   import com.mcleodgaming.ssf2.audio.*;
   import com.mcleodgaming.ssf2.controllers.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.enums.*;
   import com.mcleodgaming.ssf2.modapi.*;
   import com.mcleodgaming.ssf2.modes.*;
   import com.mcleodgaming.ssf2.modhost.ModHost;
   import com.mcleodgaming.ssf2.modhost.ModPatches;
   import com.mcleodgaming.ssf2.util.*;
   import flash.display.*;
   import flash.events.*;
   import flash.geom.*;
   import flash.text.*;
   import flash.utils.getTimer;

   public class ExpansionEventMenu extends EventMenu
   {
      override public function updateDisplay() : void
      {
         super.updateDisplay();
         this.paintExpansionHover();
      }

      override public function makeEvents() : void
      {
         super.makeEvents();
         this.armListWheel();
      }

      override public function killEvents() : void
      {
         this.disarmListWheel();
         super.killEvents();
      }

      private function armListWheel() : void
      {
         var host:DisplayObject = null;
         host = m_subMenu && m_subMenu.stage ? m_subMenu.stage : m_subMenu;
         if(!host)
         {
            return;
         }
         host.removeEventListener(MouseEvent.MOUSE_WHEEL,this.onListWheel,true);
         host.addEventListener(MouseEvent.MOUSE_WHEEL,this.onListWheel,true,0);
      }

      private function disarmListWheel() : void
      {
         var host:DisplayObject = null;
         host = m_subMenu && m_subMenu.stage ? m_subMenu.stage : m_subMenu;
         if(!host)
         {
            return;
         }
         host.removeEventListener(MouseEvent.MOUSE_WHEEL,this.onListWheel,true);
      }

      /** One wheel notch moves one row. The visible window is 11 rows. */
      private function onListWheel(e:MouseEvent) : void
      {
         var extra:int = 0;
         var step:Number = 0;
         var notches:int = 0;
         var dir:Number = 0;
         var nextY:Number = 0;
         if(!m_subMenu || !m_subMenu.scroller || !this.m_scrollTop || this.m_scrollHeight <= 0 || !this.m_events)
         {
            return;
         }
         extra = int(Math.max(0,this.m_events.length - 11));
         if(extra < 1)
         {
            return;
         }
         step = this.m_scrollHeight / extra;
         notches = int(Math.abs(e.delta) / 3);
         if(notches < 1)
         {
            notches = 1;
         }
         dir = e.delta > 0 ? -1 : 1;
         nextY = m_subMenu.scroller.y + dir * step * notches;
         if(nextY < this.m_scrollTop.y)
         {
            nextY = this.m_scrollTop.y;
         }
         if(nextY > this.m_scrollTop.y + this.m_scrollHeight)
         {
            nextY = this.m_scrollTop.y + this.m_scrollHeight;
         }
         m_subMenu.scroller.y = nextY;
         this.repositionList();
      }

      override public function setExpansionList(list:Array) : void
      {
         this.m_expansionList = list != null ? list : [];
         if(this.m_listMode == "expansions")
         {
            this.applyListMode(false);
         }
      }

      override public function attachExpansionChrome() : void
      {
         if(this.m_chromeAttached)
         {
            return;
         }
         this.buildToggleUI();
         this.m_chromeAttached = true;
         if(Boolean(this.eventSelectHand))
         {
            this.eventSelectHand.listTogglePush = this.listToggleHelper;
         }
         if(this.m_showCount > 0)
         {
            if(Boolean(this.m_vanillaBtn))
            {
               this.m_vanillaBtn.addEventListener(MouseEvent.CLICK,this.vanillaToggle_CLICK);
            }
            if(Boolean(this.m_expansionsBtn))
            {
               this.m_expansionsBtn.addEventListener(MouseEvent.CLICK,this.expansionsToggle_CLICK);
            }
         }
      }

      override protected function detachExpansionChrome() : void
      {
         if(!this.m_chromeAttached && !this.m_toggleBar)
         {
            return;
         }
         this.m_chromeAttached = false;
         if(Boolean(this.eventSelectHand))
         {
            this.eventSelectHand.listTogglePush = null;
         }
         if(Boolean(this.m_vanillaBtn))
         {
            this.m_vanillaBtn.removeEventListener(MouseEvent.CLICK,this.vanillaToggle_CLICK);
         }
         if(Boolean(this.m_expansionsBtn))
         {
            this.m_expansionsBtn.removeEventListener(MouseEvent.CLICK,this.expansionsToggle_CLICK);
         }
         if(Boolean(this.m_toggleBar) && Boolean(this.m_toggleBar.parent))
         {
            this.m_toggleBar.parent.removeChild(this.m_toggleBar);
         }
         this.m_toggleBar = null;
         this.m_vanillaBtn = null;
         this.m_expansionsBtn = null;
         if(this.m_listMode != "vanilla")
         {
            this.m_listMode = "vanilla";
            this.applyListMode(true);
         }
      }

      override protected function expansionChromeWanted() : Boolean
      {
         return ModHost.getModInfo("expansions") != null && ModHost.isModEnabled("expansions");
      }

      override public function setListMode(mode:String) : void
      {
         if(!this.m_chromeAttached)
         {
            mode = "vanilla";
         }
         if(mode != "vanilla" && mode != "expansions" && mode != "downloads")
         {
            mode = "vanilla";
         }
         if(this.m_listMode == mode)
         {
            this.refreshToggleLabels();
            return;
         }
         this.dbg("setListMode " + this.m_listMode + " -> " + mode);
         this.m_listMode = mode;
         this.applyListMode(true);
      }

      override protected function requestListMode(mode:String) : void
      {
         if(!this.m_chromeAttached)
         {
            return;
         }
         if(this.m_listMode == mode && this.m_pendingListMode == null)
         {
            return;
         }
         if(this.m_pendingListMode == mode)
         {
            return;
         }
         this.dbg("requestListMode " + mode);
         this.m_pendingListMode = mode;
         this.m_blockClicks = true;
         this.m_idleFrames = 0;
         this.lockSelectHand(true);
         if(mode == "downloads")
         {
            this.m_downloadNotice = "Contacting GameBanana...";
            this.m_downloadList = [];
            this.requestDownloadList();
         }
         this.armFramePump();
      }

      override protected function armFramePump() : void
      {
         if(this.m_frameArmed || !m_subMenu)
         {
            return;
         }
         this.m_frameArmed = true;
         m_subMenu.addEventListener(Event.ENTER_FRAME,this.onMenuFrame);
      }

      override protected function disarmFramePump() : void
      {
         if(!this.m_frameArmed || !m_subMenu)
         {
            return;
         }
         this.m_frameArmed = false;
         m_subMenu.removeEventListener(Event.ENTER_FRAME,this.onMenuFrame);
      }

      override protected function onMenuFrame(e:Event) : void
      {
         var mode:String = null;
         this.m_idleFrames++;
         if(this.m_pendingListMode != null)
         {
            mode = this.m_pendingListMode;
            this.m_pendingListMode = null;
            this.dbg("pendingListMode apply " + mode);
            this.m_switchingList = true;
            this.m_blockClicks = true;
            try
            {
               this.setListMode(mode);
               if(Boolean(this.eventSelectHand))
               {
                  this.eventSelectHand.resetPosition();
                  this.eventSelectHand.resetLetGo();
               }
            }
            catch(err:*)
            {
               this.dbg("pendingListMode FAIL " + mode + ": " + err);
            }
            this.m_switchingList = false;
            this.m_idleFrames = 0;
         }
         if(this.m_pendingListMode == null && this.selectButtonIsUp())
         {
            if(this.m_idleFrames > 8)
            {
               this.m_blockClicks = false;
               this.lockSelectHand(false);
               this.disarmFramePump();
            }
         }
         else
         {
            this.m_idleFrames = 0;
         }
      }

      override protected function lockSelectHand(locked:Boolean) : void
      {
         if(Boolean(this.eventSelectHand))
         {
            this.eventSelectHand.setInputLocked(locked);
         }
      }

      override protected function selectButtonIsUp() : Boolean
      {
         var i:int = 0;
         var c:Controller = null;
         try
         {
            while(i < SaveData.Controllers.length)
            {
               c = SaveData.Controllers[i];
               if(Boolean(c) && (c.IsDown(c._BUTTON2) || c.IsDown(c._START)))
               {
                  return false;
               }
               i++;
            }
         }
         catch(err:*)
         {
         }
         return true;
      }

      override protected function requestDownloadList() : void
      {
         if(this.m_downloadRequested)
         {
            this.dbg("requestDownloadList already in flight");
            return;
         }
         this.m_downloadRequested = true;
         try
         {
            this.dbg("requestDownloadList door");
            ModHost.door("event_expansions.browseDownloads",[],null);
         }
         catch(err:*)
         {
            this.dbg("requestDownloadList FAIL: " + err);
            this.setDownloadList([],"Could not reach the downloader");
         }
      }

      override public function setDownloadList(list:Array, notice:String = null) : void
      {
         var prevCount:int = this.m_downloadList != null ? int(this.m_downloadList.length) : 0;
         if(!this.m_chromeAttached)
         {
            this.m_downloadRequested = false;
            return;
         }
         this.m_downloadRequested = false;
         this.m_downloadList = list != null ? list : [];
         if(Boolean(notice))
         {
            this.m_downloadNotice = notice;
         }
         else if(this.m_downloadList.length == 0)
         {
            this.m_downloadNotice = "No events posted yet - check back later";
         }
         else
         {
            this.m_downloadNotice = "";
         }
         this.dbg("setDownloadList n=" + this.m_downloadList.length + " notice=" + this.m_downloadNotice);
         if(this.m_listMode != "downloads" && this.m_pendingListMode != "downloads")
         {
            return;
         }
         if(this.m_listMode == "downloads" && this.m_downloadList.length == prevCount && this.m_downloadList.length == 0)
         {
            this.dbg("setDownloadList notice-only");
            if(Boolean(this.m_unlockIcon) && Boolean(this.m_unlockIcon.visible))
            {
               this.m_unlockIcon.eventName.text = this.m_downloadNotice;
               return;
            }
         }
         if(this.m_pendingListMode == "downloads")
         {
            return;
         }
         this.applyListMode(false);
      }

      override public function setDownloadStatus(id:String, message:String) : void
      {
         var i:int = 0;
         this.dbg("setDownloadStatus " + id + ": " + message);
         while(i < this.m_downloadList.length)
         {
            if(this.m_downloadList[i] && this.m_downloadList[i].id === id)
            {
               this.m_downloadList[i].description = message;
               break;
            }
            i++;
         }
         if(this.m_listMode == "downloads" && Boolean(this.m_currentEvent) && this.m_currentEvent.id === id)
         {
            this.m_currentEvent.description = message;
            this.updateDisplay();
         }
      }

      override protected function buildDownloadRows() : Array
      {
         var out:Array = [];
         var i:int = 0;
         out.push({
            "id":"__downloads_back",
            "name":"< Back to events",
            "description":"Return to the installed expansion events.",
            "chooseCharacter":false,
            "backEntry":true
         });
         while(i < this.m_downloadList.length)
         {
            out.push(this.m_downloadList[i]);
            i++;
         }
         return out;
      }

      override protected function dbg(msg:String) : void
      {
      }

      override public function getListMode() : String
      {
         return this.m_listMode;
      }

      override protected function buildToggleUI() : void
      {
         var fmt:TextFormat = new TextFormat("_sans",12,16777215,true);
         this.m_toggleBar = new MovieClip();
         this.m_toggleBar.x = -130;
         this.m_toggleBar.y = -155;
         this.m_vanillaBtn = this.makeToggleClip("VANILLA",fmt);
         this.m_vanillaBtn.x = 0;
         this.m_expansionsBtn = this.makeToggleClip("EXPANSIONS",fmt);
         this.m_expansionsBtn.x = 110;
         this.m_toggleBar.addChild(this.m_vanillaBtn);
         this.m_toggleBar.addChild(this.m_expansionsBtn);
         m_subMenu.addChild(this.m_toggleBar);
         this.refreshToggleLabels();
      }

      override protected function makeToggleClip(label:String, fmt:TextFormat) : MovieClip
      {
         var mc:MovieClip = new MovieClip();
         var tf:TextField = new TextField();
         mc.graphics.beginFill(3355443,0.9);
         mc.graphics.lineStyle(1,16777215,0.85);
         mc.graphics.drawRoundRect(0,0,100,22,6,6);
         mc.graphics.endFill();
         tf.defaultTextFormat = fmt;
         tf.text = label;
         tf.width = 100;
         tf.height = 20;
         tf.y = 1;
         tf.selectable = false;
         tf.mouseEnabled = false;
         mc.addChild(tf);
         mc.buttonMode = true;
         mc.mouseChildren = false;
         mc.name = label;
         return mc;
      }

      override protected function refreshToggleLabels() : void
      {
         this.tintToggle(this.m_vanillaBtn,this.m_listMode == "vanilla");
         this.tintToggle(this.m_expansionsBtn,this.m_listMode == "expansions");
      }

      override protected function tintToggle(mc:MovieClip, on:Boolean) : void
      {
         if(!mc)
         {
            return;
         }
         mc.graphics.clear();
         mc.graphics.beginFill(on ? 4473924 : 2236962,0.95);
         mc.graphics.lineStyle(2,on ? 16777136 : 10066329,0.95);
         mc.graphics.drawRoundRect(0,0,100,22,6,6);
         mc.graphics.endFill();
      }

      override protected function applyListMode(resetScroll:Boolean) : void
      {
         var needed:int = 0;
         var btn:EventButton = null;
         var source:Array = null;
         if(this.m_listMode == "downloads")
         {
            source = this.buildDownloadRows();
         }
         else
         {
            source = this.m_listMode == "expansions" ? this.m_expansionList : this.m_vanillaEvents;
         }
         if(!source)
         {
            source = [];
         }
         this.m_events = this.padEventList(source);
         needed = int(this.m_events.length);
         while(this.m_eventButtons.length > needed)
         {
            btn = this.m_eventButtons.pop();
            if(Boolean(btn) && Boolean(btn.ButtonInstance))
            {
               btn.killEvents();
               btn.ButtonInstance.removeEventListener(MouseEvent.CLICK,this.event_CLICK);
               btn.ButtonInstance.removeEventListener(MouseEvent.MOUSE_OVER,this.event_MOUSE_OVER);
               btn.ButtonInstance.removeEventListener(MouseEvent.MOUSE_OUT,this.event_MOUSE_OUT);
               if(Boolean(btn.ButtonInstance.parent))
               {
                  btn.ButtonInstance.parent.removeChild(btn.ButtonInstance);
               }
            }
         }
         while(this.m_eventButtons.length < needed)
         {
            btn = new EventButton(ResourceManager.getLibraryMC("eventIconMC"));
            this.m_eventButtons.push(btn);
            this.m_eventContainer.addChild(btn.ButtonInstance);
            if(m_showCount > 0)
            {
               btn.ButtonInstance.addEventListener(MouseEvent.CLICK,this.event_CLICK);
               btn.ButtonInstance.addEventListener(MouseEvent.MOUSE_OVER,this.event_MOUSE_OVER);
               btn.ButtonInstance.addEventListener(MouseEvent.MOUSE_OUT,this.event_MOUSE_OUT);
            }
         }
         if(Boolean(this.eventSelectHand))
         {
            this.eventSelectHand.syncButtons(this.m_eventButtons);
         }
         if(resetScroll)
         {
            m_subMenu.scroller.y = this.m_scrollTop.y;
            this.m_eventContainer.y = this.m_listLocation.y;
         }
         this.m_currentEvent = null;
         this.clearPreviewBitmap();
         this.clearPreviewCharacter();
         this.updateDisplay();
         this.refreshToggleLabels();
         if(m_showCount > 0)
         {
            try
            {
               this.paintEventRows();
            }
            catch(paintErr:*)
            {
               this.dbg("paintEventRows FAIL: " + paintErr);
            }
         }
      }

      override protected function padEventList(source:Array) : Array
      {
         var out:Array = [];
         var i:int = 0;
         var padId:int = 0;
         if(Boolean(source))
         {
            i = 0;
            while(i < source.length)
            {
               out.push(source[i]);
               i++;
            }
         }
         padId = 0;
         while(out.length < 20)
         {
            out.push({
               "id":"_pad_" + padId,
               "name":"",
               "description":"",
               "placeholder":true
            });
            padId++;
         }
         return out;
      }

      override protected function listToggleHelper() : void
      {
         ModHost.triggerMenuRumble(m_lastControllerIndex >= 0 ? m_lastControllerIndex : 0);
         SoundQueue.instance.playSoundEffect("menu_hover");
         this.setListMode(this.m_listMode == "expansions" ? "vanilla" : "expansions");
         GameLog.write("[event_expansions] listToggle mode=" + this.m_listMode);
      }

      override protected function clearPreviewBitmap() : void
      {
         if(Boolean(this.m_previewBitmap) && Boolean(this.m_previewBitmap.parent))
         {
            this.m_previewBitmap.parent.removeChild(this.m_previewBitmap);
         }
         this.m_previewBitmap = null;
      }

      override protected function attachExpansionPreview(previewer:MovieClip, bd:BitmapData) : void
      {
         if(!previewer || !bd)
         {
            return;
         }
         Utils.tryToGotoAndStop(previewer,1);
         this.placePreviewBitmap(previewer,bd);
      }

      private function placePreviewBitmap(previewer:MovieClip, bd:BitmapData) : void
      {
         if(!previewer || !bd)
         {
            return;
         }
         this.clearPreviewBitmap();
         this.m_previewBitmap = new Bitmap(bd);
         this.m_previewBitmap.smoothing = true;
         this.m_previewBitmap.name = "expPreviewBmp";
         this.m_previewBitmap.x = EXP_PREVIEW_X;
         this.m_previewBitmap.y = EXP_PREVIEW_Y;
         this.m_previewBitmap.width = EXP_PREVIEW_W;
         this.m_previewBitmap.height = EXP_PREVIEW_H;
         previewer.addChild(this.m_previewBitmap);
         this.ensureEventUiAbovePreviewer();
      }

      override protected function ensureEventUiAbovePreviewer() : void
      {
         var names:Array = ["previewer","eventName","eventNum","eventDesc","rank_txt","desc_txt","sample"];
         var n:String = null;
         var d:DisplayObject = null;
         var i:int = 0;
         if(!m_subMenu || !m_subMenu.previewer)
         {
            return;
         }
         try
         {
            i = 0;
            while(i < names.length)
            {
               n = String(names[i]);
               if(n in m_subMenu && Boolean(m_subMenu[n]))
               {
                  d = m_subMenu[n] as DisplayObject;
                  if(Boolean(d) && d.parent == m_subMenu)
                  {
                     m_subMenu.setChildIndex(d,m_subMenu.numChildren - 1);
                  }
               }
               i++;
            }
         }
         catch(zErr:*)
         {
         }
      }

      override protected function getPreviewCharacterHost() : MovieClip
      {
         try
         {
            if(Boolean(m_subMenu) && Boolean(m_subMenu.previewer))
            {
               return m_subMenu.previewer as MovieClip;
            }
         }
         catch(err:*)
         {
         }
         return null;
      }

      /** The card is a baked frame per stock id. Expansion rows draw on it, or stop on Select Character. */
      private function paintExpansionHover() : void
      {
         var ev:Object = null;
         var charId:String = null;
         var costume:int = 0;
         var previewer:MovieClip = null;
         ev = this.m_currentEvent;
         if(!ev || !ev.expansion || ev.seriesStart || ev.placeholder)
         {
            return;
         }
         if(ev.downloadEntry || ev.downloadItem || ev.backEntry || ev.noticeEntry)
         {
            return;
         }
         if(this.wantsSelectFrame(ev))
         {
            this.clearPreviewCharacter();
            this.showSelectCharacterFrame();
            return;
         }
         charId = ev.previewCharacter != null ? String(ev.previewCharacter) : "";
         costume = -1;
         if(ev.previewCostume != null && String(ev.previewCostume).length > 0)
         {
            costume = int(ev.previewCostume);
         }
         this.showPreviewCharacter(charId,costume);
      }

      private function wantsSelectFrame(ev:Object) : Boolean
      {
         var id:String = null;
         if(!ev)
         {
            return false;
         }
         if(ev.chooseCharacter === true || String(ev.chooseCharacter).toLowerCase() == "true")
         {
            return true;
         }
         id = ev.previewCharacter != null ? String(ev.previewCharacter) : "";
         return id.length < 1 || id.toLowerCase() == "(player)";
      }

      private function showSelectCharacterFrame() : void
      {
         var previewer:MovieClip = null;
         this.clearPreviewBitmap();
         try
         {
            previewer = m_subMenu ? m_subMenu.previewer as MovieClip : null;
         }
         catch(prevErr:*)
         {
            previewer = null;
         }
         if(!previewer)
         {
            return;
         }
         Utils.tryToGotoAndStop(previewer,"BattleRevolution");
         if(Boolean(this.m_currentEvent) && this.m_currentEvent.previewBitmapData is BitmapData)
         {
            this.placePreviewBitmap(previewer,this.m_currentEvent.previewBitmapData as BitmapData);
         }
         GameLog.write("[event_expansions] preview frame=BattleRevolution");
      }

      /** Copy the Select Character banner off the stock card. Do not keep that event's picture. */
      override protected function clearPreviewCharacter() : void
      {
         if(Boolean(this.m_previewCharMC) && Boolean(this.m_previewCharMC.parent))
         {
            this.m_previewCharMC.parent.removeChild(this.m_previewCharMC);
         }
         this.m_previewCharMC = null;
         this.stripPreviewChildren(this.getPreviewCharacterHost());
         try
         {
            if(Boolean(m_subMenu) && Boolean(m_subMenu.previewer))
            {
               this.stripPreviewChildren(m_subMenu.previewer as MovieClip);
            }
            if(Boolean(m_subMenu) && Boolean(m_subMenu.sample))
            {
               m_subMenu.sample.visible = false;
            }
         }
         catch(clearErr:*)
         {
         }
      }

      private function stripPreviewChildren(host:MovieClip) : void
      {
         var i:int = 0;
         var child:DisplayObject = null;
         if(!host)
         {
            return;
         }
         i = host.numChildren - 1;
         while(i >= 0)
         {
            child = host.getChildAt(i);
            if(child && (child.name == "expPreviewChar" || child.name == "expPreviewSeries" || child.name == "expPreviewName" || child.name == "expSelectBanner"))
            {
               host.removeChildAt(i);
            }
            i--;
         }
      }

      override protected function showPreviewCharacter(charId:String, costumeId:int) : void
      {
         var previewer:MovieClip = null;
         var clip:MovieClip = null;
         var link:String = null;
         if(!charId || charId.length < 1 || charId.toLowerCase() == "(player)")
         {
            return;
         }
         try
         {
            previewer = m_subMenu ? m_subMenu.previewer as MovieClip : null;
         }
         catch(err:*)
         {
            previewer = null;
         }
         if(!previewer)
         {
            GameLog.write("[event_expansions] tune no previewer char=" + charId);
            return;
         }
         this.clearPreviewCharacter();
         Utils.tryToGotoAndStop(previewer,"TroubledKing");
         this.clearPreviewBitmap();
         if(Boolean(this.m_currentEvent) && this.m_currentEvent.previewBitmapData is BitmapData)
         {
            this.placePreviewBitmap(previewer,this.m_currentEvent.previewBitmapData as BitmapData);
         }
         link = charId + "_event";
         clip = this.takeEventPortrait(previewer,charId,costumeId);
         if(!clip)
         {
            GameLog.write("[event_expansions] preview char=" + charId + " link=" + link + " missing");
            return;
         }
         this.placeEventPortrait(previewer,clip);
         GameLog.write("[event_expansions] preview char=" + charId + " link=" + link + " loader=player_info_loader");
      }

      /** Same call the stock preview frame makes: paLoader.getPortrait(id, "event"). */
      private function takeEventPortrait(previewer:MovieClip, charId:String, costumeId:int) : MovieClip
      {
         var pa:* = null;
         var clip:MovieClip = null;
         var costumeData:Object = null;
         try
         {
            pa = previewer.paLoader;
            if(pa && pa.getPortrait is Function)
            {
               clip = pa.getPortrait(charId,"event",costumeId) as MovieClip;
            }
         }
         catch(paErr:*)
         {
            clip = null;
         }
         if(clip)
         {
            return clip;
         }
         clip = ResourceManager.getLibraryMC(charId + "_event");
         if(!clip)
         {
            return null;
         }
         try
         {
            costumeData = SSF2API.getCostumeData(charId,-1,costumeId);
            Utils.setColorFilter(clip,costumeData);
            Utils.replacePalette(clip,costumeData ? costumeData.paletteSwapPA : null,1,true,true);
         }
         catch(colorErr:*)
         {
            GameLog.write("[event_expansions] preview color failed char=" + charId);
         }
         return clip;
      }

      private function placeEventPortrait(previewer:MovieClip, clip:MovieClip) : void
      {
         var loader:MovieClip = null;
         try
         {
            loader = previewer.player_info_loader as MovieClip;
         }
         catch(loadErr:*)
         {
            loader = null;
         }
         if(!loader)
         {
            GameLog.write("[event_expansions] preview no player_info_loader");
            return;
         }
         while(loader.numChildren > 0)
         {
            loader.removeChildAt(0);
         }
         clip.mouseEnabled = false;
         clip.mouseChildren = false;
         loader.addChild(clip);
         this.m_previewCharMC = clip;
         this.ensureEventUiAbovePreviewer();
      }

      override protected function paintEventRows() : void
      {
         var allStarNumber:int = 0;
         var eventNumber:int = 0;
         var madeUnlockIcon:Boolean = false;
         var i:int = 0;
         var rankStr:String = null;
         var btnMC:MovieClip = null;
         var ev:Object = null;
         var y_offset:Number = 0;
         this.m_unlockIcon.visible = false;
         while(i < this.m_events.length)
         {
            if(i >= this.m_eventButtons.length || !this.m_eventButtons[i] || !this.m_eventButtons[i].ButtonInstance)
            {
               break;
            }
            ev = this.m_events[i];
            btnMC = this.m_eventButtons[i].ButtonInstance;
            btnMC.eventName.text = ev != null && ev.name != null ? String(ev.name) : "";
            btnMC.name = "e" + i;
            btnMC.y = y_offset * 23;
            btnMC.visible = true;
            btnMC.mouseEnabled = !(ev && ev.installed);
            btnMC.addEventListener(MouseEvent.CLICK,this.event_CLICK);
            btnMC.addEventListener(MouseEvent.MOUSE_OVER,this.event_MOUSE_OVER);
            btnMC.addEventListener(MouseEvent.MOUSE_OUT,this.event_MOUSE_OUT);
            if(Boolean(ev) && Boolean(ev.placeholder))
            {
               btnMC.eventName.text = "";
               btnMC.complete.visible = false;
               btnMC.alpha = 0.35;
               y_offset++;
               i++;
               continue;
            }
            btnMC.alpha = 1;
            if(this.isChromeRow(ev))
            {
               btnMC.complete.visible = false;
               if(Boolean(ev.installed))
               {
                  btnMC.alpha = 0.45;
               }
               y_offset++;
               if(Boolean(ev.backEntry) && this.m_listMode == "downloads")
               {
                  y_offset = this.placeDownloadNotice(y_offset);
               }
               i++;
               continue;
            }
            this.xpPaintRank(btnMC,ev);
            if(Boolean(ev.expansion) || Boolean(ev.seriesStart))
            {
               y_offset++;
               i++;
               continue;
            }
            if(Boolean(ev.dev) && !Main.DEBUG)
            {
               btnMC.visible = false;
            }
            else
            {
               if(Boolean(ev.dev) && Boolean(Main.DEBUG))
               {
                  btnMC.eventName.text += " (dev)";
               }
               y_offset++;
            }
            if(Boolean(ev.allStar))
            {
               allStarNumber++;
            }
            else
            {
               eventNumber++;
            }
            if(this.xpEventLocked(Boolean(ev.allStar),allStarNumber,eventNumber))
            {
               if(Main.DEBUG)
               {
                  btnMC.eventName.text += " (*)";
               }
               else
               {
                  btnMC.visible = false;
               }
            }
            if(!madeUnlockIcon)
            {
               rankStr = this.xpUnlockIconMessage(allStarNumber,eventNumber);
               if(rankStr != null)
               {
                  madeUnlockIcon = true;
                  this.m_unlockIcon.eventName.text = rankStr;
               }
               if(madeUnlockIcon)
               {
                  this.m_unlockIcon.visible = true;
                  this.m_eventContainer.addChild(this.m_unlockIcon);
                  this.m_unlockIcon.y = y_offset * 23;
                  y_offset++;
                  madeUnlockIcon = true;
               }
            }
            i++;
         }
      }

      private function xpPaintRank(btnMC:MovieClip, ev:Object) : void
      {
         var rankStr:String = null;
         var winRec:* = SaveData.Records.events.wins[ev.id];
         if(winRec != null && winRec !== undefined && winRec !== false)
         {
            rankStr = winRec.rank != null ? String(winRec.rank).toUpperCase() : "";
            if(rankStr.length > 0)
            {
               btnMC.complete.gotoAndStop(rankStr);
            }
            btnMC.complete.visible = true;
         }
         else
         {
            btnMC.complete.visible = false;
         }
      }

      private function xpEventLocked(allStar:Boolean, allStarNumber:int, eventNumber:int) : Boolean
      {
         if(allStar)
         {
            return Boolean(allStarNumber === 1 && !SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_01] || allStarNumber === 2 && !SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_06] || allStarNumber === 3 && !SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_07] || allStarNumber === 4 && !SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_08] || allStarNumber === 5 && !SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_09] || allStarNumber === 6 && !SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_BETA]);
         }
         return Boolean(eventNumber >= 11 && eventNumber <= 20 && !SaveData.Unlocks[Unlockable.EVENTS_11_20] || eventNumber >= 21 && eventNumber <= 30 && !SaveData.Unlocks[Unlockable.EVENTS_21_30] || eventNumber >= 31 && eventNumber <= 36 && !SaveData.Unlocks[Unlockable.EVENTS_31_36] || eventNumber >= 37 && eventNumber <= 44 && !SaveData.Unlocks[Unlockable.EVENTS_37_44] || eventNumber >= 45 && eventNumber <= 50 && !SaveData.Unlocks[Unlockable.EVENTS_45_50] || eventNumber >= 51 && eventNumber <= 51 && !SaveData.Unlocks[Unlockable.EVENTS_51]);
      }

      /** Text for the "must complete" row shown once in the list, or null when this row does not get it. */
      private function xpUnlockIconMessage(allStarNumber:int, eventNumber:int) : String
      {
         if(!SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_01] && eventNumber === 10)
         {
            return "Must complete events 1-10";
         }
         if(!SaveData.Unlocks[Unlockable.EVENTS_11_20] && allStarNumber === 1)
         {
            return "Must complete All Star v0.1";
         }
         if(!SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_06] && eventNumber === 20)
         {
            return "Must complete events 11-20";
         }
         if(!SaveData.Unlocks[Unlockable.EVENTS_21_30] && allStarNumber === 2)
         {
            return "Must complete All Star v0.6";
         }
         if(!SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_07] && eventNumber === 30)
         {
            return "Must complete events 21-30";
         }
         if(!SaveData.Unlocks[Unlockable.EVENTS_31_36] && allStarNumber === 3)
         {
            return "Must complete All Star v0.7";
         }
         if(!SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_08] && eventNumber === 36)
         {
            return "Must complete events 31-36";
         }
         if(!SaveData.Unlocks[Unlockable.EVENTS_37_44] && allStarNumber === 4)
         {
            return "Must complete All Star v0.8";
         }
         if(!SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_09] && eventNumber === 44)
         {
            return "Must complete events 37-44";
         }
         if(!SaveData.Unlocks[Unlockable.EVENTS_45_50] && allStarNumber === 5)
         {
            return "Must complete All Star v0.9";
         }
         if(!SaveData.Unlocks[Unlockable.EVENT_ALL_STAR_BETA] && eventNumber === 50)
         {
            return "Must complete events 45-50";
         }
         if(!SaveData.Records.events.wins["AllStarBattleBeta"] && !SaveData.Unlocks[Unlockable.EVENTS_51] && allStarNumber === 6)
         {
            return "Must complete All Star Beta";
         }
         if(Boolean(SaveData.Records.events.wins["AllStarBattleBeta"] && !SaveData.Unlocks[Unlockable.EVENT_ARANK]) && Boolean(!SaveData.Unlocks[Unlockable.EVENTS_51]) && allStarNumber === 6)
         {
            return "Must A-rank or above every event";
         }
         return null;
      }

      override protected function vanillaToggle_CLICK(e:MouseEvent) : void
      {
         ModHost.triggerMenuRumble(m_lastControllerIndex >= 0 ? m_lastControllerIndex : 0);
         SoundQueue.instance.playSoundEffect("menu_hover");
         this.setListMode("vanilla");
      }

      override protected function expansionsToggle_CLICK(e:MouseEvent) : void
      {
         ModHost.triggerMenuRumble(m_lastControllerIndex >= 0 ? m_lastControllerIndex : 0);
         SoundQueue.instance.playSoundEffect("menu_hover");
         this.setListMode("expansions");
      }

      override protected function startDownload(entry:Object) : void
      {
         if(!entry)
         {
            return;
         }
         this.dbg("startDownload " + entry.id + " modId=" + entry.modId);
         this.setDownloadStatus(String(entry.id),"Starting download...");
         try
         {
            ModHost.door("event_expansions.installEvent",[entry.modId,entry.name],null);
         }
         catch(err:*)
         {
            this.dbg("startDownload FAIL: " + err);
            this.setDownloadStatus(String(entry.id),"Download failed to start");
         }
      }

      override protected function placeDownloadNotice(slot:int) : int
      {
         if(this.m_downloadNotice == null || this.m_downloadNotice.length <= 0)
         {
            return slot;
         }
         this.m_unlockIcon.eventName.text = this.m_downloadNotice;
         this.m_unlockIcon.complete.visible = false;
         this.m_unlockIcon.alpha = 0.75;
         this.m_unlockIcon.mouseEnabled = false;
         this.m_unlockIcon.mouseChildren = false;
         this.m_unlockIcon.visible = true;
         this.m_eventContainer.addChild(this.m_unlockIcon);
         this.m_unlockIcon.y = slot * 23;
         return slot + 1;
      }

      override protected function isChromeRow(ev:Object) : Boolean
      {
         var id:String = null;
         if(!ev)
         {
            return true;
         }
         if(Boolean(ev.placeholder) || Boolean(ev.noticeEntry) || Boolean(ev.backEntry) || Boolean(ev.downloadEntry) || Boolean(ev.downloadItem))
         {
            return true;
         }
         id = ev.id != null ? String(ev.id) : "";
         return id.indexOf("__downloads_") == 0 || id.indexOf("_pad_") == 0 || id.indexOf("gb.") == 0;
      }

      override protected function handleEventClick(e:MouseEvent) : void
      {
         var now:int = 0;
         var index:int = 0;
         var ev:Object = null;
         if(this.m_switchingList || this.m_pendingListMode != null)
         {
            this.m_idleFrames = 0;
            return;
         }
         if(this.m_blockClicks)
         {
            this.m_idleFrames = 0;
            return;
         }
         // The select hand can re-fire CLICK on a held button every frame; one row, one action.
         now = int(getTimer());
         if(now - this.m_lastClickAt < 250)
         {
            return;
         }
         this.m_lastClickAt = now;
         ModHost.triggerMenuRumble(m_lastControllerIndex >= 0 ? m_lastControllerIndex : 0);
         index = int(this.findEvent(e.target as MovieClip));
         ev = index >= 0 && index < this.m_events.length ? this.m_events[index] : null;
         this.dbg("click mode=" + this.m_listMode + " index=" + index + " of " + this.m_events.length + " id=" + (ev ? ev.id : "none") + " notice=" + (ev ? ev.noticeEntry : "") + " back=" + (ev ? ev.backEntry : "") + " item=" + (ev ? ev.downloadItem : ""));
         if(index >= 0 && index < this.m_events.length)
         {
            this.m_currentEvent = ev;
            if(Boolean(this.m_currentEvent.placeholder))
            {
               this.m_currentEvent = null;
               this.updateDisplay();
               return;
            }
            if(this.m_listMode == "downloads")
            {
               if(Boolean(this.m_currentEvent.backEntry))
               {
                  SoundQueue.instance.playSoundEffect("menu_hover");
                  this.requestListMode("expansions");
                  return;
               }
               if(Boolean(this.m_currentEvent.installed))
               {
                  return;
               }
               if(Boolean(this.m_currentEvent.downloadItem))
               {
                  SoundQueue.instance.playSoundEffect("menu_selectstage");
                  this.startDownload(this.m_currentEvent);
                  return;
               }
               this.dbg("click ignored downloads chrome id=" + this.m_currentEvent.id);
               return;
            }
            if(Boolean(this.m_currentEvent.seriesStart))
            {
               removeSelf();
               SoundQueue.instance.playSoundEffect("menu_selectstage");
               try
               {
                  ModHost.setSessionFlag("event_expansions.seriesStart",this.m_currentEvent.seriesId || this.m_currentEvent.id);
               }
               catch(seriesErr:*)
               {
               }
               if(!MenuController.eventMenu.isOnscreen())
               {
                  MenuController.eventMenu.show();
               }
               return;
            }
            if(Boolean(this.m_currentEvent.downloadEntry))
            {
               SoundQueue.instance.playSoundEffect("menu_hover");
               this.requestListMode("downloads");
               return;
            }
            if(this.isChromeRow(this.m_currentEvent))
            {
               this.dbg("click ignored chrome id=" + this.m_currentEvent.id);
               return;
            }
            this.beginListedEvent();
         }
      }

      /** Deep link: open this id from the list on screen, not the vanilla eventList index. */
      public function startEventById(eventId:String) : Boolean
      {
         var hit:int = 0;
         if(!eventId || eventId.length < 1 || !this.m_events)
         {
            return false;
         }
         if(this.indexOfListed(this.m_events,eventId) < 0 && this.indexOfListed(this.m_expansionList,eventId) >= 0)
         {
            this.setListMode("expansions");
         }
         hit = this.indexOfListed(this.m_events,eventId);
         if(hit < 0)
         {
            return false;
         }
         this.m_currentEvent = this.m_events[hit];
         this.beginListedEvent();
         GameLog.write("[event_expansions] startEventById id=" + eventId);
         return true;
      }

      private function indexOfListed(list:Array, eventId:String) : int
      {
         var i:int = 0;
         var ev:Object = null;
         if(!list)
         {
            return -1;
         }
         while(i < list.length)
         {
            ev = list[i];
            if(ev && String(ev.id || "") == eventId && !this.isChromeRow(ev))
            {
               return i;
            }
            i++;
         }
         return -1;
      }

      private function beginListedEvent() : void
      {
         removeSelf();
         this.applyStageBackground();
         if(Boolean(this.m_currentEvent.chooseCharacter))
         {
            SoundQueue.instance.playSoundEffect("menu_selectstage");
            MenuController.eventMatchCharacterMenu.reset();
            if(!MenuController.eventMatchCharacterMenu.isOnscreen())
            {
               MenuController.eventMatchCharacterMenu.show();
            }
         }
         else
         {
            this.xpStartEventMatch();
         }
      }

      private function applyStageBackground() : void
      {
         var bgStage:String = this.m_currentEvent && this.m_currentEvent.stageBackground ? String(this.m_currentEvent.stageBackground) : "";
         if(bgStage.indexOf("pack:") == 0)
         {
            bgStage = "";
         }
         ModHost.setSessionFlag("backgroundStage",bgStage.length > 0 ? bgStage : null);
         GameLog.write("[event_expansions] backgroundStage id=" + (bgStage.length > 0 ? bgStage : "none"));
      }

      private function xpStartEventMatch() : void
      {
         try
         {
            SoundQueue.instance.playSoundEffect("menu_selectstage");
            SoundQueue.instance.playSoundEffect("menu_crowd");
            this.m_game = new Game(Main.MAXPLAYERS,Mode.EVENT);
            var modeClass:Class = ModHost.door(ModPatches.EVENT_MODE_CLASS,[this.m_currentEvent],null) as Class;
            if(modeClass == null)
            {
               try
               {
                  var vanillaMode:* = ResourceManager.getResourceByID("event_mode").getProp("mode");
                  if(vanillaMode is Class)
                  {
                     modeClass = vanillaMode as Class;
                  }
               }
               catch(modeErr:*)
               {
               }
            }
            this.m_modeInstance = new EventMode(this.m_game,{"eventMatchID":this.m_currentEvent.id},{"classAPI":modeClass});
            this.m_modeInstance.PreviousMenu = this;
            try
            {
               ModHost.setSessionFlag("event_expansions.currentEventId",this.m_currentEvent.id);
               if(Boolean(this.m_currentEvent.expansion))
               {
                  ModHost.setSessionFlag("event_expansions.seriesId",this.m_currentEvent.seriesId || null);
                  ModHost.setSessionFlag("event_expansions.seriesIndex",this.m_currentEvent.seriesIndex != null ? this.m_currentEvent.seriesIndex : null);
               }
            }
            catch(flagErr:*)
            {
            }
         }
         catch(startErr:*)
         {
            GameLog.write("[event_expansions] event start failed id=" + (this.m_currentEvent ? this.m_currentEvent.id : "none") + ": " + startErr);
            throw startErr;
         }
      }
   }
}
