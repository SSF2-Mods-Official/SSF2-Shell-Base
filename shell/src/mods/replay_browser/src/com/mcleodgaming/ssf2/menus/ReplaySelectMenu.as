package com.mcleodgaming.ssf2.menus
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.audio.*;
   import com.mcleodgaming.ssf2.controllers.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.enums.*;
   import com.mcleodgaming.ssf2.modapi.ModAPI;
   import com.mcleodgaming.ssf2.modhost.ModHost;
   import com.mcleodgaming.ssf2.net.*;
   import com.mcleodgaming.ssf2.util.ResourceManager;
   import com.mcleodgaming.ssf2.util.Utils;
   import ssf2mm.shared.JsonFile;
   import flash.display.*;
   import flash.events.*;
   import flash.filesystem.*;
   import flash.geom.*;
   import flash.net.*;
   import flash.text.*;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import ssf2mm.replay.ReplayFiles;
   import ssf2mm.replay.ReplayLabels;
   
   public class ReplaySelectMenu extends Menu
   {
      
      private var m_isDragging:Boolean;
      
      private var m_replayFiles:Array;
      
      private var m_replayContainer:MovieClip;
      
      private var m_replayMask:MovieClip;
      
      private var m_replayButtons:Vector.<NewsButton>;
      
      private var m_listLocation:Point;
      
      private var m_scrollTop:Point;
      
      private var m_scrollHeight:Number;
      
      private var m_selectHand:NewsMenuHand;
      
      private var m_currentIndex:int;
      
      private var m_metadataCache:flash.utils.Dictionary;
      
      private var m_launching:Boolean = false;
      
      private var m_stagePreviewer:MovieClip;
      
      private var m_thumbLoader:Loader;
      
      private var m_folderBtn:MovieClip;
      
      private var m_chooseReplayBtn:MovieClip;
      
      private var m_resetFolderBtn:MovieClip;
      
      private var m_vaultChrome:MovieClip;
      
      private var m_charIconRow:MovieClip;
      
      public function ReplaySelectMenu()
      {
         super();
         m_subMenu = ResourceManager.getLibraryMC("menu_news");
         m_backgroundID = "space";
         m_container.addChild(m_subMenu);
         m_subMenu.x = Main.Width / 2;
         m_subMenu.y = Main.Height / 2;
         initMenuMappings();
         m_subMenu.bg_top.visible = false;
         this.m_isDragging = false;
         this.m_currentIndex = -1;
         this.m_metadataCache = new Dictionary(true);
         this.m_thumbLoader = null;
         this.m_scrollTop = new Point(m_subMenu.scroller.x,m_subMenu.scroller.y);
         this.m_scrollHeight = 197 - m_subMenu.scroller.height;
         this.m_listLocation = new Point(-260,-30);
         this.m_replayMask = new MovieClip();
         this.m_replayMask.x = this.m_listLocation.x - 10;
         this.m_replayMask.y = this.m_listLocation.y - 10;
         this.m_replayMask.graphics.beginFill(16711680,1);
         this.m_replayMask.graphics.drawRect(0,0,576 + 20,190 + 20);
         this.m_replayMask.graphics.endFill();
         this.m_replayMask.visible = false;
         this.m_replayContainer = new MovieClip();
         this.m_replayContainer.x = this.m_listLocation.x;
         this.m_replayContainer.y = this.m_listLocation.y;
         this.m_replayFiles = new Array();
         this.m_replayButtons = new Vector.<NewsButton>();
         m_subMenu.addChild(this.m_replayContainer);
         m_subMenu.addChild(this.m_replayMask);
         this.m_replayContainer.mask = this.m_replayMask;
         this.m_stagePreviewer = MovieClip(m_subMenu.thumbnail.contents.addChild(ResourceManager.getLibraryMC("stagePreviewer")));
         this.m_stagePreviewer.gotoAndStop(1);
         this.m_charIconRow = new MovieClip();
         m_subMenu.thumbnail.addChild(this.m_charIconRow);
         this.m_vaultChrome = ResourceManager.getLibraryMC("menu_vault");
         this.m_vaultChrome.x = m_subMenu.x;
         this.m_vaultChrome.y = m_subMenu.y;
         this.m_vaultChrome.replays_btn.visible = false;
         this.m_vaultChrome.replays_btn.mouseEnabled = false;
         this.m_vaultChrome.replays_btn.mouseChildren = false;
         this.m_vaultChrome.intro_btn.visible = false;
         this.m_vaultChrome.intro_btn.mouseEnabled = false;
         this.m_vaultChrome.intro_btn.mouseChildren = false;
         this.m_vaultChrome.intro2_btn.visible = false;
         this.m_vaultChrome.intro2_btn.mouseEnabled = false;
         this.m_vaultChrome.intro2_btn.mouseChildren = false;
         this.m_vaultChrome.intro3_btn.visible = false;
         this.m_vaultChrome.intro3_btn.mouseEnabled = false;
         this.m_vaultChrome.intro3_btn.mouseChildren = false;
         this.m_folderBtn = ReplayLabels.makeFolderButton("Choose Folder");
         this.m_folderBtn.x = 146;
         this.m_folderBtn.y = -24;
         this.m_folderBtn.buttonMode = true;
         this.m_folderBtn.useHandCursor = true;
         this.m_vaultChrome.addChild(this.m_folderBtn);
         this.m_chooseReplayBtn = ReplayLabels.makeFolderButton("Choose Replay");
         this.m_chooseReplayBtn.x = 146;
         this.m_chooseReplayBtn.y = -1;
         this.m_chooseReplayBtn.buttonMode = true;
         this.m_chooseReplayBtn.useHandCursor = true;
         this.m_vaultChrome.addChild(this.m_chooseReplayBtn);
         this.m_resetFolderBtn = ReplayLabels.makeFolderButton("Reset Folder");
         this.m_resetFolderBtn.x = 146;
         this.m_resetFolderBtn.y = 22;
         this.m_resetFolderBtn.buttonMode = true;
         this.m_resetFolderBtn.useHandCursor = true;
         this.m_vaultChrome.addChild(this.m_resetFolderBtn);
         this.updateFolderBtnState();
         m_container.addChild(this.m_vaultChrome);
         this.m_selectHand = new NewsMenuHand(m_subMenu,this.m_replayButtons,this.backMain_CLICK);
         this.m_selectHand.topBoundPush = this.handPushListUpHelper;
         this.m_selectHand.bottomBoundPush = this.handPushListDownHelper;
         this.m_selectHand.addClickEventClipHitTest(this.m_vaultChrome.bg_top.back_btn);
         this.m_selectHand.addClickEventClipHitTest(this.m_folderBtn);
         this.m_selectHand.addClickEventClipHitTest(this.m_chooseReplayBtn);
         this.m_selectHand.addClickEventClipHitTest(this.m_resetFolderBtn);
      }
      
      private function loadReplayFiles() : void
      {
         var _loc1_:File = null;
         var _loc2_:Array = null;
         var _loc3_:int = 0;
         var _loc4_:File = null;
         this.m_replayFiles = [];
         try
         {
            _loc1_ = ReplayFiles.getReplayFolder();
            if(Boolean(_loc1_.exists) && Boolean(_loc1_.isDirectory))
            {
               _loc2_ = _loc1_.getDirectoryListing();
               _loc3_ = 0;
               while(_loc3_ < _loc2_.length)
               {
                  _loc4_ = _loc2_[_loc3_] as File;
                  if(_loc4_.extension == "ssfrec")
                  {
                     this.m_replayFiles.push(_loc4_);
                  }
                  _loc3_++;
               }
               this.m_replayFiles.sort(ReplayFiles.compareReplayDateNewestFirst);
            }
         }
         catch(e:*)
         {
            trace("[replay_browser] loadReplayFiles failed: " + e);
         }
      }
      
      private function rebuildButtons() : void
      {
         var _loc2_:NewsButton = null;
         if(this.m_selectHand)
         {
            this.m_selectHand.killEvents();
         }
         var _loc1_:int = 0;
         while(_loc1_ < this.m_replayButtons.length)
         {
            if(this.m_replayButtons[_loc1_].ButtonInstance.parent)
            {
               this.m_replayContainer.removeChild(this.m_replayButtons[_loc1_].ButtonInstance);
            }
            _loc1_++;
         }
         this.m_replayButtons = new Vector.<NewsButton>();
         _loc1_ = 0;
         while(_loc1_ < this.m_replayFiles.length)
         {
            _loc2_ = new NewsButton(ResourceManager.getLibraryMC("newsItemMC"));
            this.m_replayButtons.push(_loc2_);
            this.m_replayContainer.addChildAt(_loc2_.ButtonInstance,0);
            _loc1_++;
         }
         if(Boolean(this.m_selectHand) && Boolean(this.m_selectHand.HandMC.parent))
         {
            this.m_selectHand.HandMC.parent.removeChild(this.m_selectHand.HandMC);
         }
         this.m_selectHand = new NewsMenuHand(m_subMenu,this.m_replayButtons,this.backMain_CLICK);
         this.m_selectHand.topBoundPush = this.handPushListUpHelper;
         this.m_selectHand.bottomBoundPush = this.handPushListDownHelper;
         this.m_selectHand.addClickEventClipHitTest(this.m_vaultChrome.bg_top.back_btn);
         this.m_selectHand.addClickEventClipHitTest(this.m_folderBtn);
         this.m_selectHand.addClickEventClipHitTest(this.m_chooseReplayBtn);
         this.m_selectHand.addClickEventClipHitTest(this.m_resetFolderBtn);
      }
      
      override public function show() : void
      {
         this.m_launching = false;
         this.m_currentIndex = -1;
         this.loadReplayFiles();
         this.rebuildButtons();
         this.updateThumbnail();
         super.show();
         SoundQueue.instance.playMusic("menumusic",0);
      }
      
      private function parseReplayMeta(param1:File) : ReplayData
      {
         var result:ReplayData;
         var raw:ByteArray = null;
         var stream:FileStream = null;
         var f:File = param1;
         var key:String = ReplayFiles.metaKey(f);
         if(this.m_metadataCache[key] !== undefined)
         {
            return this.m_metadataCache[key] as ReplayData;
         }
         result = null;
         try
         {
            raw = new ByteArray();
            stream = new FileStream();
            stream.open(f,FileMode.READ);
            stream.readBytes(raw);
            stream.close();
            raw.uncompress();
            result = new ReplayData(Main.MAXPLAYERS);
            result.importReplay(raw.readUTF());
         }
         catch(e:*)
         {
            result = null;
         }
         this.m_metadataCache[key] = result;
         return result;
      }
      
      private function clearThumbnailContents() : void
      {
         while(m_subMenu.thumbnail.contents.numChildren > 0)
         {
            m_subMenu.thumbnail.contents.removeChildAt(0);
         }
         if(this.m_thumbLoader != null)
         {
            try
            {
               this.m_thumbLoader.unload();
            }
            catch(e:*)
            {
            }
            this.m_thumbLoader = null;
         }
         this.m_stagePreviewer = null;
      }
      
      private function updateThumbnail() : void
      {
         var f:File;
         var rd:ReplayData;
         var ms:Object;
         var stageId:String;
         var infoParts:Array;
         var lineup:String;
         var rules:String;
         var displayName:String;
         var displayParts:Array;
         var thumbFile:File;
         var baseName:String = null;
         var _self:ReplaySelectMenu = null;
         var capW:Number = NaN;
         var capH:Number = NaN;
         var tw:Number = 256;
         var th:Number = 144;
         m_subMenu.thumbnail.contents.mask = null;
         this.clearThumbnailContents();
         while(this.m_charIconRow.numChildren > 0)
         {
            this.m_charIconRow.removeChildAt(0);
         }
         if(this.m_currentIndex < 0 || this.m_currentIndex >= this.m_replayFiles.length)
         {
            m_subMenu.thumbnail.title.text = this.m_replayFiles.length == 0 ? "No replays found." : "";
            this.m_stagePreviewer = MovieClip(m_subMenu.thumbnail.contents.addChild(ResourceManager.getLibraryMC("stagePreviewer")));
            this.m_stagePreviewer.gotoAndStop(1);
            this.centerAndFillStagePreviewer(tw,th);
            return;
         }
         f = this.m_replayFiles[this.m_currentIndex] as File;
         rd = this.parseReplayMeta(f);
         if(rd == null)
         {
            m_subMenu.thumbnail.title.text = "[unreadable]";
            this.m_stagePreviewer = MovieClip(m_subMenu.thumbnail.contents.addChild(ResourceManager.getLibraryMC("stagePreviewer")));
            this.m_stagePreviewer.gotoAndStop(1);
            this.centerAndFillStagePreviewer(tw,th);
            return;
         }
         ms = rd.MatchSettings;
         stageId = ms ? ms.stage : null;
         infoParts = [ReplayLabels.modeLabel(rd.GameMode)];
         lineup = ReplayLabels.lineupLabel(rd.PlayerData);
         rules = ReplayLabels.rulesLabel(ms);
         if(lineup)
         {
            infoParts.push(lineup);
         }
         if(rules)
         {
            infoParts.push(rules);
         }
         infoParts.push(rd.Timestamp.toLocaleDateString() + " (" + ReplayLabels.durationLabel(rd.FrameCount) + ")");
         displayName = f.name.replace(/\.ssfrec$/i,"");
         displayParts = displayName.split(" - ");
         if(displayParts.length > 1)
         {
            displayName = displayParts.slice(1).join(" - ");
         }
         displayName = this.fixEmptyCharNames(displayName,rd.PlayerData);
         m_subMenu.thumbnail.title.text = displayName + "\n" + infoParts.join("\n");
         this.buildCharIconRow(rd.PlayerData,f);
         thumbFile = null;
         try
         {
            baseName = f.name.replace(/\.ssfrec$/i,"");
            thumbFile = f.parent.resolvePath(baseName + ".png");
            if(!thumbFile.exists)
            {
               thumbFile = null;
            }
         }
         catch(e_t:*)
         {
            thumbFile = null;
         }
         if(thumbFile != null)
         {
            this.m_thumbLoader = new Loader();
            _self = this;
            capW = tw;
            capH = th;
            this.m_thumbLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(param1:Event):void
            {
               var _loc3_:Number = NaN;
               var _loc4_:Number = NaN;
               var _loc5_:Number = NaN;
               if(_self.m_thumbLoader == null)
               {
                  return;
               }
               var _loc2_:Bitmap = _self.m_thumbLoader.content as Bitmap;
               if(_loc2_ != null && capW > 0 && capH > 0)
               {
                  _loc3_ = capW / _loc2_.width;
                  _loc4_ = capH / _loc2_.height;
                  _loc5_ = Math.max(_loc3_,_loc4_);
                  _loc2_.width = Math.round(_loc2_.width * _loc5_);
                  _loc2_.height = Math.round(_loc2_.height * _loc5_);
                  _self.m_thumbLoader.x = -(_loc2_.width / 2);
                  _self.m_thumbLoader.y = -(_loc2_.height / 2);
               }
               m_subMenu.thumbnail.contents.addChild(_self.m_thumbLoader);
            });
            this.m_thumbLoader.load(new URLRequest(thumbFile.url));
         }
         else
         {
            this.m_stagePreviewer = MovieClip(m_subMenu.thumbnail.contents.addChild(ResourceManager.getLibraryMC("stagePreviewer")));
            if(Boolean(stageId) && stageId != "")
            {
               Utils.tryToGotoAndStop(this.m_stagePreviewer,stageId);
            }
            else
            {
               this.m_stagePreviewer.gotoAndStop(1);
            }
            this.centerAndFillStagePreviewer(tw,th);
         }
      }
      
      private function centerAndFillStagePreviewer(param1:Number, param2:Number) : void
      {
         if(this.m_stagePreviewer == null)
         {
            return;
         }
         var _loc3_:Rectangle = this.m_stagePreviewer.getBounds(this.m_stagePreviewer);
         var _loc4_:Number = _loc3_.width > 0 ? _loc3_.width : Number(this.m_stagePreviewer.width);
         var _loc5_:Number = _loc3_.height > 0 ? _loc3_.height : Number(this.m_stagePreviewer.height);
         var _loc6_:Number = 1;
         if(_loc4_ > 0 && _loc5_ > 0 && param1 > 0 && param2 > 0)
         {
            _loc6_ = Math.max(param1 / _loc4_,param2 / _loc5_);
            this.m_stagePreviewer.scaleX = _loc6_;
            this.m_stagePreviewer.scaleY = _loc6_;
         }
         var _loc7_:Number = _loc3_.x + _loc3_.width / 2;
         var _loc8_:Number = _loc3_.y + _loc3_.height / 2;
         this.m_stagePreviewer.x = 0 - _loc7_ * _loc6_;
         this.m_stagePreviewer.y = 0 - _loc8_ * _loc6_;
         var _loc9_:MovieClip = new MovieClip();
         _loc9_.graphics.beginFill(0,1);
         _loc9_.graphics.drawRect(-param1 / 2,-param2 / 2,param1 > 0 ? param1 : 256,param2 > 0 ? param2 : 144);
         _loc9_.graphics.endFill();
         m_subMenu.thumbnail.contents.addChild(_loc9_);
         m_subMenu.thumbnail.contents.mask = _loc9_;
      }
      
      private function fixEmptyCharNames(param1:String, param2:Array) : String
      {
         var charToDisplay:Object;
         var fixes:Array = null;
         var i:int = 0;
         var fixIdx:int = 0;
         var meta:Object = null;
         var k:String = null;
         var p:Object = null;
         var charId:String = null;
         var label:String = param1;
         var pd:Array = param2;
         if(pd == null || pd.length == 0)
         {
            return label;
         }
         charToDisplay = {};
         try
         {
            meta = ResourceManager.getResourceByID("mappings").getProp("metadata").character;
            for(k in meta)
            {
               if(meta[k].name)
               {
                  charToDisplay[k] = String(meta[k].name);
               }
            }
         }
         catch(e_cd:*)
         {
         }
         fixes = [];
         i = 0;
         while(i < pd.length)
         {
            p = pd[i];
            if(!(p == null || p.exist === false))
            {
               charId = p.character;
               if(!charId || charId == "random" || Boolean(p.isRandom))
               {
                  fixes.push(null);
               }
               else
               {
                  fixes.push(charToDisplay[charId] || null);
               }
            }
            i++;
         }
         fixIdx = 0;
         return label.replace(/\(([^)]*)\)/g,function(param1:String, param2:String, ... rest):String
         {
            if(fixIdx >= fixes.length)
            {
               return param1;
            }
            var _loc4_:* = fixes[fixIdx++];
            if(param2 != "")
            {
               return param1;
            }
            return _loc4_ ? "(" + _loc4_ + ")" : param1;
         });
      }
      
      private function buildCharIconRow(param1:Array, param2:File = null) : void
      {
         var _loc4_:Array = null;
         var _loc10_:Object = null;
         var _loc11_:String = null;
         var _loc12_:String = null;
         var _loc13_:int = 0;
         var _loc14_:RegExp = null;
         var _loc15_:Object = null;
         var _loc16_:String = null;
         var _loc17_:Object = null;
         var _loc18_:String = null;
         var _loc19_:int = 0;
         var _loc20_:MovieClip = null;
         var _loc21_:Number = NaN;
         while(this.m_charIconRow.numChildren > 0)
         {
            this.m_charIconRow.removeChildAt(0);
         }
         if(param1 == null || param1.length == 0)
         {
            return;
         }
         var _loc3_:Object = {};
         try
         {
            _loc10_ = ResourceManager.getResourceByID("mappings").getProp("metadata").character;
            for(_loc11_ in _loc10_)
            {
               if(_loc10_[_loc11_].name)
               {
                  _loc3_[String(_loc10_[_loc11_].name).toLowerCase()] = _loc11_;
               }
            }
         }
         catch(e_m:*)
         {
         }
         _loc4_ = [];
         if(param2 != null)
         {
            _loc12_ = param2.name.replace(/\.ssfrec$/i,"");
            _loc13_ = _loc12_.indexOf(" - ");
            if(_loc13_ >= 0)
            {
               _loc12_ = _loc12_.substr(_loc13_ + 3);
            }
            _loc14_ = /\(([^)]+)\)/g;
            while(true)
            {
               _loc15_ = _loc14_.exec(_loc12_);
               if(_loc15_ == null)
               {
                  break;
               }
               _loc16_ = String(_loc15_[1]);
               _loc4_.push(_loc3_[_loc16_.toLowerCase()] || null);
            }
         }
         var _loc5_:Number = 20;
         var _loc6_:Number = 4;
         var _loc7_:Number = 0;
         var _loc8_:int = 0;
         var _loc9_:int = 0;
         while(_loc9_ < param1.length)
         {
            _loc17_ = param1[_loc9_];
            if(Boolean(_loc17_) && Boolean(_loc17_.exist !== false) && Boolean(_loc17_.character))
            {
               _loc18_ = _loc17_.character;
               if(_loc18_ == "random" || Boolean(_loc17_.isRandom))
               {
                  _loc18_ = _loc8_ < _loc4_.length ? _loc4_[_loc8_] : null;
               }
               if(Boolean(_loc18_) && _loc18_ != "random")
               {
                  _loc19_ = _loc17_.costume !== undefined && _loc17_.costume !== null ? int(_loc17_.costume) : -1;
                  _loc20_ = ResourceManager.getLibraryMC(_loc18_ + "_stock");
                  if(_loc20_ != null)
                  {
                     Utils.setColorFilterCharacter(_loc20_,-1,_loc18_,_loc19_,false,true);
                     if(_loc20_.width > 0)
                     {
                        _loc21_ = _loc5_ / _loc20_.width;
                        _loc20_.scaleX = _loc20_.scaleY = _loc21_;
                     }
                     _loc20_.x = _loc7_;
                     _loc20_.y = 0;
                     this.m_charIconRow.addChild(_loc20_);
                     _loc7_ += _loc5_ + _loc6_;
                  }
               }
               _loc8_++;
            }
            _loc9_++;
         }
         this.m_charIconRow.x = m_subMenu.thumbnail.title.x;
         this.m_charIconRow.y = m_subMenu.thumbnail.title.y - _loc5_ - 4;
      }
      
      override public function makeEvents() : void
      {
         var _loc3_:File = null;
         var _loc4_:String = null;
         var _loc5_:Array = null;
         var _loc6_:ReplayData = null;
         if(m_showCount == 0)
         {
            findSubMenuButtons();
            findSpecificMenuButtons(this.m_vaultChrome.bg_top);
         }
         super.makeEvents();
         resetAllButtons();
         this.m_vaultChrome.bg_top.back_btn.addEventListener(MouseEvent.CLICK,this.backMain_CLICK);
         this.m_vaultChrome.bg_top.back_btn.addEventListener(MouseEvent.ROLL_OVER,this.back_ROLL_OVER);
         this.m_vaultChrome.bg_top.home_btn.addEventListener(MouseEvent.CLICK,this.home_CLICK);
         m_subMenu.scroller.addEventListener(MouseEvent.MOUSE_DOWN,this.scroll_CLICK);
         m_subMenu.stage.addEventListener(MouseEvent.MOUSE_MOVE,this.scroll_MOVE);
         m_subMenu.addEventListener(MouseEvent.MOUSE_UP,this.scroll_RELEASE);
         this.m_folderBtn.addEventListener(MouseEvent.CLICK,this.folderBtn_CLICK);
         this.m_chooseReplayBtn.addEventListener(MouseEvent.CLICK,this.chooseReplayBtn_CLICK);
         this.m_resetFolderBtn.addEventListener(MouseEvent.CLICK,this.resetFolderBtn_CLICK);
         this.m_selectHand.makeEvents();
         m_subMenu.scroller.y = this.m_scrollTop.y;
         this.m_replayContainer.y = this.m_listLocation.y;
         this.m_replayContainer.x = this.m_listLocation.x;
         var _loc1_:int = 0;
         var _loc2_:int = 0;
         while(_loc2_ < this.m_replayFiles.length)
         {
            _loc3_ = this.m_replayFiles[_loc2_] as File;
            _loc4_ = _loc3_.name.replace(/\.ssfrec$/i,"");
            _loc5_ = _loc4_.split(" - ");
            if(_loc5_.length > 1)
            {
               _loc4_ = _loc5_.slice(1).join(" - ");
            }
            _loc6_ = this.parseReplayMeta(_loc3_);
            if(_loc6_ != null)
            {
               _loc4_ = this.fixEmptyCharNames(_loc4_,_loc6_.PlayerData);
            }
            this.m_replayButtons[_loc2_].ButtonInstance.status.gotoAndStop("read");
            this.m_replayButtons[_loc2_].ButtonInstance.title.text = _loc4_;
            this.m_replayButtons[_loc2_].ButtonInstance.y = _loc1_ * 23;
            this.m_replayButtons[_loc2_].ButtonInstance.addEventListener(MouseEvent.CLICK,this.replay_CLICK);
            this.m_replayButtons[_loc2_].ButtonInstance.addEventListener(MouseEvent.MOUSE_OVER,this.replay_MOUSE_OVER);
            this.m_replayButtons[_loc2_].ButtonInstance.addEventListener(MouseEvent.MOUSE_OUT,this.replay_MOUSE_OUT);
            this.m_replayButtons[_loc2_].makeEvents();
            _loc1_++;
            _loc2_++;
         }
         Main.Root.stage.addEventListener(Event.ENTER_FRAME,manageMenuMappings);
         setMenuMappingFocus();
      }
      
      override public function killEvents() : void
      {
         super.killEvents();
         if(this.m_thumbLoader != null)
         {
            try
            {
               this.m_thumbLoader.unload();
            }
            catch(e_u:*)
            {
            }
            this.m_thumbLoader = null;
         }
         this.m_vaultChrome.bg_top.back_btn.removeEventListener(MouseEvent.CLICK,this.backMain_CLICK);
         this.m_vaultChrome.bg_top.back_btn.removeEventListener(MouseEvent.ROLL_OVER,this.back_ROLL_OVER);
         this.m_vaultChrome.bg_top.home_btn.removeEventListener(MouseEvent.CLICK,this.home_CLICK);
         m_subMenu.scroller.removeEventListener(MouseEvent.MOUSE_DOWN,this.scroll_CLICK);
         if(m_subMenu.stage)
         {
            m_subMenu.stage.removeEventListener(MouseEvent.MOUSE_MOVE,this.scroll_MOVE);
         }
         m_subMenu.removeEventListener(MouseEvent.MOUSE_UP,this.scroll_RELEASE);
         this.m_folderBtn.removeEventListener(MouseEvent.CLICK,this.folderBtn_CLICK);
         this.m_chooseReplayBtn.removeEventListener(MouseEvent.CLICK,this.chooseReplayBtn_CLICK);
         this.m_resetFolderBtn.removeEventListener(MouseEvent.CLICK,this.resetFolderBtn_CLICK);
         var _loc1_:int = 0;
         while(_loc1_ < this.m_replayButtons.length)
         {
            this.m_replayButtons[_loc1_].ButtonInstance.visible = true;
            this.m_replayButtons[_loc1_].killEvents();
            this.m_replayButtons[_loc1_].ButtonInstance.removeEventListener(MouseEvent.CLICK,this.replay_CLICK);
            this.m_replayButtons[_loc1_].ButtonInstance.removeEventListener(MouseEvent.MOUSE_OVER,this.replay_MOUSE_OVER);
            this.m_replayButtons[_loc1_].ButtonInstance.removeEventListener(MouseEvent.MOUSE_OUT,this.replay_MOUSE_OUT);
            _loc1_++;
         }
         this.m_selectHand.killEvents();
         MovieClip(m_subMenu.scroller).stopDrag();
         this.m_isDragging = false;
         Main.Root.stage.removeEventListener(Event.ENTER_FRAME,manageMenuMappings);
      }
      
      private function findReplayIndex(param1:MovieClip) : int
      {
         var _loc2_:int = 0;
         while(_loc2_ < this.m_replayButtons.length)
         {
            if(this.m_replayButtons[_loc2_].ButtonInstance == param1)
            {
               return _loc2_;
            }
            _loc2_++;
         }
         return -1;
      }
      
      private function replay_CLICK(param1:MouseEvent) : void
      {
         try
         {
            ModAPI.triggerMenuRumble(m_lastControllerIndex >= 0 ? m_lastControllerIndex : 0);
         }
         catch(rumbleErr:*)
         {
            try
            {
               ModHost.triggerMenuRumble(m_lastControllerIndex >= 0 ? m_lastControllerIndex : 0);
            }
            catch(hostErr:*)
            {
            }
         }
         var _loc2_:int = int(this.findReplayIndex(param1.target as MovieClip));
         if(this.m_launching || GameController.isStarted)
         {
            return;
         }
         if(_loc2_ < 0 || _loc2_ >= this.m_replayFiles.length)
         {
            return;
         }
         var _loc3_:File = this.m_replayFiles[_loc2_] as File;
         SoundQueue.instance.playSoundEffect("menu_select");
         this.launchReplayFile(_loc3_);
      }
      
      private function replay_MOUSE_OVER(param1:MouseEvent) : void
      {
         SoundQueue.instance.playSoundEffect("menu_hover");
         var _loc2_:int = int(this.findReplayIndex(param1.target as MovieClip));
         if(_loc2_ >= 0 && _loc2_ < this.m_replayFiles.length)
         {
            this.m_currentIndex = _loc2_;
            this.updateThumbnail();
            this.updateDescText(_loc2_);
         }
      }
      
      private function replay_MOUSE_OUT(param1:MouseEvent) : void
      {
         this.m_currentIndex = -1;
         this.updateThumbnail();
         if(this.m_vaultChrome.desc_txt != null)
         {
            this.m_vaultChrome.desc_txt.text = "";
         }
      }
      
      private function updateDescText(param1:int) : void
      {
         if(this.m_vaultChrome.desc_txt == null)
         {
            return;
         }
         if(param1 < 0 || param1 >= this.m_replayFiles.length)
         {
            this.m_vaultChrome.desc_txt.text = "";
            return;
         }
         var _loc2_:File = this.m_replayFiles[param1] as File;
         var _loc3_:ReplayData = this.parseReplayMeta(_loc2_);
         if(_loc3_ == null)
         {
            this.m_vaultChrome.desc_txt.text = "[unreadable]";
            return;
         }
         var _loc4_:Object = _loc3_.MatchSettings;
         var _loc5_:String = _loc4_ ? _loc4_.stage : null;
         var _loc6_:String = ReplayLabels.stagePretty(_loc5_);
         var _loc7_:String = _loc3_.Timestamp.toLocaleDateString() + "  " + _loc3_.Timestamp.toLocaleTimeString();
         this.m_vaultChrome.desc_txt.text = "Stage: " + _loc6_ + "   |   Date: " + _loc7_;
      }
      
      private function launchReplayFile(param1:File) : void
      {
         var loadedReplayData:ReplayData;
         var menu:* = null;
         if(this.m_launching)
         {
            return;
         }
         loadedReplayData = ReplayFiles.readPlayableReplay(param1);
         if(loadedReplayData == null)
         {
            return;
         }
         ReplayFiles.sanitizeMatchSettingsForImport(loadedReplayData);
         this.m_launching = true;
         // Tear down this menu before loading so ENTER_FRAME / hand press cannot
         // re-fire launch while resources load (was causing 100x load loops).
         try
         {
            this.killEvents();
         }
         catch(killErr:*)
         {
            trace("[replay_browser] launchReplayFile failed: " + killErr);
         }
         try
         {
            if(Boolean(m_container) && Boolean(m_container.parent))
            {
               this.removeSelf();
            }
         }
         catch(removeErr:*)
         {
            trace("[replay_browser] launchReplayFile failed: " + removeErr);
         }
         try
         {
            ResourceManager.flushLoadQueue();
         }
         catch(flushErr:*)
         {
            trace("[replay_browser] launchReplayFile failed: " + flushErr);
         }
         MenuController.removeAllMenus();
         // Match VaultMenu CSS routing; use the Game created by reset() for initReplay.
         if(loadedReplayData.GameMode === Mode.ONLINE)
         {
            MenuController.vsMenu.reset();
            MenuController.CurrentCharacterSelectMenu = MenuController.vsMenu;
         }
         else if(loadedReplayData.GameMode === Mode.ONLINE_ARENA || loadedReplayData.GameMode === Mode.ARENA)
         {
            MenuController.arenaCharacterSelectMenu.reset();
            MenuController.CurrentCharacterSelectMenu = MenuController.arenaCharacterSelectMenu;
         }
         else if(loadedReplayData.GameMode === Mode.TARGET_TEST)
         {
            MenuController.targetTestMenu.reset();
            MenuController.CurrentCharacterSelectMenu = MenuController.targetTestMenu;
         }
         else if(loadedReplayData.GameMode === Mode.HOME_RUN_CONTEST)
         {
            MenuController.homeRunContestMenu.reset();
            MenuController.CurrentCharacterSelectMenu = MenuController.homeRunContestMenu;
         }
         else if(loadedReplayData.GameMode === Mode.MULTIMAN)
         {
            MenuController.multimanCharacterSelectMenu.reset();
            MenuController.CurrentCharacterSelectMenu = MenuController.multimanCharacterSelectMenu;
         }
         else if(loadedReplayData.GameMode === Mode.CRYSTAL_SMASH)
         {
            MenuController.crystalSmashCharacterMenu.reset();
            MenuController.CurrentCharacterSelectMenu = MenuController.crystalSmashCharacterMenu;
         }
         else if(loadedReplayData.GameMode === Mode.RACE_TO_THE_FINISH)
         {
            MenuController.raceToTheFinishCharacterMenu.reset();
            MenuController.CurrentCharacterSelectMenu = MenuController.raceToTheFinishCharacterMenu;
         }
         else
         {
            MenuController.vsMenu.reset();
            MenuController.CurrentCharacterSelectMenu = MenuController.vsMenu;
         }
         menu = MenuController.CurrentCharacterSelectMenu;
         GameController.currentGame = menu.GameObj;
         menu.GameObj.ReplayDataObj = loadedReplayData;
         menu.initReplay();
      }
      
      private function backMain_CLICK(param1:MouseEvent) : void
      {
         removeSelf();
         SoundQueue.instance.playSoundEffect("menu_back");
         MenuController.vaultMenu.show();
      }
      
      private function home_CLICK(param1:MouseEvent) : void
      {
         SoundQueue.instance.playSoundEffect("menu_back");
         SoundQueue.instance.stopMusic();
         MenuController.removeAllMenus();
         MenuController.titleMenu.show();
      }
      
      private function back_ROLL_OVER(param1:MouseEvent) : void
      {
         SoundQueue.instance.playSoundEffect("menu_hover");
      }
      
      public function scroll_CLICK(param1:MouseEvent) : void
      {
         if(!this.m_isDragging)
         {
            MovieClip(m_subMenu.scroller).startDrag(false,new Rectangle(this.m_scrollTop.x,this.m_scrollTop.y,0,this.m_scrollHeight));
            this.m_isDragging = true;
         }
      }
      
      public function scroll_MOVE(param1:MouseEvent) : void
      {
         if(this.m_isDragging)
         {
            this.repositionList();
         }
      }
      
      public function scroll_RELEASE(param1:MouseEvent) : void
      {
         if(this.m_isDragging)
         {
            MovieClip(m_subMenu.scroller).stopDrag();
            this.m_isDragging = false;
         }
      }
      
      private function repositionList() : void
      {
         var _loc1_:Number = (m_subMenu.scroller.y - this.m_scrollTop.y) / this.m_scrollHeight;
         if(_loc1_ < 0.01)
         {
            _loc1_ = 0;
         }
         else if(_loc1_ > 0.99)
         {
            _loc1_ = 1;
         }
         var _loc2_:Number = 23;
         this.m_replayContainer.y = this.m_listLocation.y - _loc1_ * (_loc2_ * Math.max(0,this.m_replayFiles.length - 5));
      }
      
      private function handPushListUpHelper() : void
      {
         m_subMenu.scroller.y -= 4;
         if(m_subMenu.scroller.y < this.m_scrollTop.y)
         {
            m_subMenu.scroller.y = this.m_scrollTop.y;
         }
         this.repositionList();
      }
      
      private function handPushListDownHelper() : void
      {
         m_subMenu.scroller.y += 4;
         if(m_subMenu.scroller.y > this.m_scrollTop.y + this.m_scrollHeight)
         {
            m_subMenu.scroller.y = this.m_scrollTop.y + this.m_scrollHeight;
         }
         this.repositionList();
      }
      
      private function updateFolderBtnState() : void
      {
         var _loc1_:String = ReplayFiles.loadCustomFolderPath();
         var _loc2_:TextField = this.m_folderBtn.getChildAt(0) as TextField;
         if(_loc2_)
         {
            _loc2_.text = _loc1_ != null ? "Custom Folder" : "Choose Folder";
         }
         this.m_resetFolderBtn.visible = _loc1_ != null;
      }
      
      private function folderBtn_CLICK(param1:MouseEvent) : void
      {
         var _loc2_:File = new File();
         _loc2_.addEventListener(Event.SELECT,this.onFolderSelected);
         try
         {
            _loc2_.browseForDirectory("Select Replay Folder");
         }
         catch(e2:*)
         {
            trace("[replay_browser] folderBtn_CLICK failed: " + e2);
         }
      }
      
      private function chooseReplayBtn_CLICK(param1:MouseEvent) : void
      {
         var picker:File = new File();
         picker.addEventListener(Event.SELECT,this.onReplayFileSelected);
         try
         {
            picker.browseForOpen("Select Replay",[new FileFilter("SSF2 Replay (*.ssfrec)","*.ssfrec")]);
         }
         catch(eOpen:*)
         {
            trace("[replay_browser] chooseReplayBtn_CLICK failed: " + eOpen);
         }
      }
      
      private function onReplayFileSelected(param1:Event) : void
      {
         var picked:File = param1.target as File;
         if(picked == null || !picked.exists)
         {
            return;
         }
         if(this.m_launching || GameController.isStarted)
         {
            return;
         }
         SoundQueue.instance.playSoundEffect("menu_select");
         this.launchReplayFile(picked);
      }
      
      private function onFolderSelected(param1:Event) : void
      {
         var _loc2_:File = param1.target as File;
         if(_loc2_ == null)
         {
            return;
         }
         ReplayFiles.saveCustomFolderPath(_loc2_.nativePath);
         this.updateFolderBtnState();
         this.m_metadataCache = new Dictionary(true);
         this.killEvents();
         this.loadReplayFiles();
         this.rebuildButtons();
         this.makeEvents();
         this.updateThumbnail();
      }
      
      private function resetFolderBtn_CLICK(param1:MouseEvent) : void
      {
         ReplayFiles.clearCustomFolderPath();
         this.updateFolderBtnState();
         this.m_metadataCache = new Dictionary(true);
         this.killEvents();
         this.loadReplayFiles();
         this.rebuildButtons();
         this.makeEvents();
         this.updateThumbnail();
      }
   }
}

