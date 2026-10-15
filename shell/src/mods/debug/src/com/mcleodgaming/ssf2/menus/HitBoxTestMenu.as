// Decompiled by AS3 Sorcerer 6.78
// www.buraks.com/as3sorcerer

//com.mcleodgaming.ssf2.menus.HitBoxTestMenu

package com.mcleodgaming.ssf2.menus
{
    import __AS3__.vec.Vector;
    import flash.display.Shape;
    import flash.geom.Rectangle;
    import flash.events.MouseEvent;
    import com.mcleodgaming.ssf2.Main;
    import flash.events.Event;
    import com.mcleodgaming.ssf2.util.Key;
    import flash.geom.Point;
    import com.mcleodgaming.ssf2.util.Utils;
    import com.mcleodgaming.ssf2.controllers.*;
    import com.mcleodgaming.ssf2.audio.*;
    import com.mcleodgaming.ssf2.util.*;
    import __AS3__.vec.*;

    public class HitBoxTestMenu extends Menu 
    {

        public var hitboxes:Vector.<HitBoxTestMenuShape>;
        public var currentlyDraggingShape:HitBoxTestMenuShape;
        public var overlapContainer:Shape;

        public function HitBoxTestMenu()
        {
            super();
            this.hitboxes = new Vector.<HitBoxTestMenuShape>();
            this.hitboxes.push(new HitBoxTestMenuShape(new Rectangle(0, 0, 100, 100), 0xFF0000, false, 100, 100));
            this.hitboxes.push(new HitBoxTestMenuShape(new Rectangle(0, 0, 100, 100), 0xFF00, false, 400, 100));
            this.hitboxes.push(new HitBoxTestMenuShape(new Rectangle(0, 0, 100, 100), 0xFF, true, 100, 220));
            this.hitboxes.push(new HitBoxTestMenuShape(new Rectangle(0, 0, 100, 100), 15879682, true, 400, 220));
            var i:int;
            while (i < this.hitboxes.length)
            {
                this.hitboxes[i].sprite.addEventListener(MouseEvent.MOUSE_DOWN, (function (index:int):Function
                {
                    return (function (e:MouseEvent):void
                    {
                        currentlyDraggingShape = hitboxes[index];
                        hitboxes[index].sprite.startDrag(false);
                    });
                })(i));
                this.hitboxes[i].sprite.addEventListener(MouseEvent.MOUSE_UP, (function (index:int):Function
                {
                    return (function (e:MouseEvent):void
                    {
                        hitboxes[index].sprite.stopDrag();
                        currentlyDraggingShape = null;
                    });
                })(i));
                i = (i + 1);
            };
            this.currentlyDraggingShape = null;
        }

        override public function makeEvents():void
        {
            super.makeEvents();
            Main.Root.stage.addEventListener(Event.ENTER_FRAME, this.onEnterFrame);
            var i:int;
            while (i < this.hitboxes.length)
            {
                Main.Root.addChild(this.hitboxes[i].sprite);
                i++;
            };
            this.overlapContainer = new Shape();
            Main.Root.addChild(this.overlapContainer);
        }

        override public function killEvents():void
        {
            super.killEvents();
            Main.Root.stage.removeEventListener(Event.ENTER_FRAME, this.onEnterFrame);
            var i:int;
            while (i < this.hitboxes.length)
            {
                if (Main.Root.contains(this.hitboxes[i].sprite))
                {
                    Main.Root.removeChild(this.hitboxes[i].sprite);
                };
                i++;
            };
            this.currentlyDraggingShape = null;
            if (Main.Root.contains(this.overlapContainer))
            {
                Main.Root.removeChild(this.overlapContainer);
            };
        }

        public function onEnterFrame(e:Event):void
        {
            var result:Rectangle;
            if (this.currentlyDraggingShape)
            {
                if (Key.isDown(Key.LEFT))
                {
                    this.currentlyDraggingShape.sprite.rotation = (this.currentlyDraggingShape.sprite.rotation + 1);
                };
                if (Key.isDown(Key.RIGHT))
                {
                    this.currentlyDraggingShape.sprite.rotation = (this.currentlyDraggingShape.sprite.rotation - 1);
                };
                if (Key.isDown(Key.EQUALS))
                {
                    this.currentlyDraggingShape.sprite.scaleX = (this.currentlyDraggingShape.sprite.scaleX + 0.05);
                    this.currentlyDraggingShape.sprite.scaleY = (this.currentlyDraggingShape.sprite.scaleY + 0.05);
                };
                if (Key.isDown(Key.UNDERSCORE))
                {
                    this.currentlyDraggingShape.sprite.scaleX = (this.currentlyDraggingShape.sprite.scaleX - 0.05);
                    this.currentlyDraggingShape.sprite.scaleY = (this.currentlyDraggingShape.sprite.scaleY - 0.05);
                };
            };
            var collisionRect:Rectangle;
            var i:int;
            var j:int;
            i = 0;
            while (i < this.hitboxes.length)
            {
                this.hitboxes[i].collision = false;
                this.hitboxes[i].processed = {};
                i++;
            };
            this.overlapContainer.graphics.clear();
            this.overlapContainer.graphics.beginFill(0xFFFFFF, 0.75);
            i = 0;
            while (i < this.hitboxes.length)
            {
                j = 0;
                while (j < this.hitboxes.length)
                {
                    if (((!(i == j)) && (!(this.hitboxes[i].processed[j]))))
                    {
                        result = this.hitboxes[i].hitbox.hitTest(this.hitboxes[j].hitbox, new Point(this.hitboxes[i].sprite.x, this.hitboxes[i].sprite.y), new Point(this.hitboxes[j].sprite.x, this.hitboxes[j].sprite.y), false, false, new Point(this.hitboxes[i].sprite.scaleX, this.hitboxes[i].sprite.scaleY), new Point(this.hitboxes[j].sprite.scaleX, this.hitboxes[j].sprite.scaleY), Utils.forceBase360((360 - this.hitboxes[i].sprite.rotation)), Utils.forceBase360((360 - this.hitboxes[j].sprite.rotation)));
                        if (result)
                        {
                            this.overlapContainer.graphics.drawRect(result.x, result.y, result.width, result.height);
                            this.hitboxes[i].collision = true;
                            this.hitboxes[j].collision = this.hitboxes[i].collision;
                        };
                        this.hitboxes[i].processed[j] = true;
                        this.hitboxes[j].processed[i] = true;
                    };
                    j++;
                };
                i++;
            };
            i = 0;
            while (i < this.hitboxes.length)
            {
                this.hitboxes[i].update();
                i++;
            };
        }


    }
}//package com.mcleodgaming.ssf2.menus

