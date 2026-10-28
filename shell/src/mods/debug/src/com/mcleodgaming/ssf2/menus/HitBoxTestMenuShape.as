// Decompiled by AS3 Sorcerer 6.78
// www.buraks.com/as3sorcerer

//com.mcleodgaming.ssf2.menus.HitBoxTestMenuShape

package com.mcleodgaming.ssf2.menus
{
    import flash.display.Sprite;
    import com.mcleodgaming.ssf2.engine.HitBoxSprite;
    import flash.geom.Point;
    import flash.geom.Rectangle;

    public class HitBoxTestMenuShape 
    {

        public var sprite:Sprite;
        public var hitbox:HitBoxSprite;
        public var circular:Boolean;
        public var color:int;
        public var processed:Object;
        public var collision:Boolean;

        public function HitBoxTestMenuShape(rect:Rectangle, colorRGB:int, isCircular:Boolean, xPos:Number, yPos:Number)
        {
            this.sprite = new Sprite();
            this.hitbox = new HitBoxSprite(0, rect, isCircular, null, new Point(), new Point(1, 1), 0, null, 0);
            this.color = colorRGB;
            this.circular = isCircular;
            this.sprite.x = xPos;
            this.sprite.y = yPos;
            this.processed = {};
            this.collision = false;
            this.sprite.graphics.beginFill(this.color, 1);
            if (this.circular)
            {
                this.sprite.graphics.drawCircle((this.hitbox.BoundingBox.x + (this.hitbox.BoundingBox.width / 2)), (this.hitbox.BoundingBox.y + (this.hitbox.BoundingBox.height / 2)), (this.hitbox.BoundingBox.width / 2));
            }
            else
            {
                this.sprite.graphics.drawRect(this.hitbox.BoundingBox.x, this.hitbox.BoundingBox.y, this.hitbox.BoundingBox.width, this.hitbox.BoundingBox.height);
            };
            this.sprite.graphics.endFill();
        }

        public function update():void
        {
            this.sprite.alpha = ((this.collision) ? 1 : 0.5);
        }


    }
}//package com.mcleodgaming.ssf2.menus

