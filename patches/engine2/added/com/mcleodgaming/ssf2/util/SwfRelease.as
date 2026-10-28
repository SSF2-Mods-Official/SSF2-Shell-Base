package com.mcleodgaming.ssf2.util
{
   import flash.display.*;
   import flash.system.*;
   
   public class SwfRelease
   {
      
      public function SwfRelease()
      {
         super();
      }
      
      public static function context() : LoaderContext
      {
         var _loc1_:LoaderContext = new LoaderContext(false,new ApplicationDomain(ApplicationDomain.currentDomain));
         _loc1_.allowCodeImport = true;
         return _loc1_;
      }
      
      public static function forget(param1:Object, param2:Loader) : int
      {
         var _loc3_:ApplicationDomain = null;
         var _loc4_:* = undefined;
         var _loc5_:int = 0;
         if(!param1 || !param2)
         {
            return 0;
         }
         try
         {
            _loc3_ = param2.contentLoaderInfo.applicationDomain;
         }
         catch(domainErr:*)
         {
         }
         if(!_loc3_)
         {
            return 0;
         }
         for(_loc4_ in param1)
         {
            try
            {
               if(Boolean(param1[_loc4_]) && _loc3_.hasDefinition(String(_loc4_)) && _loc3_.getDefinition(String(_loc4_)) == param1[_loc4_].ref)
               {
                  param1[_loc4_] = null;
                  delete param1[_loc4_];
                  _loc5_++;
               }
            }
            catch(keyErr:*)
            {
            }
         }
         return _loc5_;
      }
      
      public static function release(param1:Loader) : void
      {
         var _loc2_:DisplayObject = null;
         var _loc3_:DisplayObjectContainer = null;
         if(!param1)
         {
            return;
         }
         try
         {
            _loc2_ = param1.content;
         }
         catch(contentErr:*)
         {
         }
         if(_loc2_ is MovieClip)
         {
            try
            {
               MovieClip(_loc2_).stop();
            }
            catch(stopErr:*)
            {
            }
         }
         if(_loc2_ is DisplayObjectContainer)
         {
            _loc3_ = _loc2_ as DisplayObjectContainer;
            try
            {
               while(_loc3_.numChildren > 0)
               {
                  _loc3_.removeChildAt(_loc3_.numChildren - 1);
               }
            }
            catch(childErr:*)
            {
            }
         }
         _loc2_ = null;
         _loc3_ = null;
         try
         {
            param1.unloadAndStop(true);
         }
         catch(unloadErr:*)
         {
         }
      }
   }
}
