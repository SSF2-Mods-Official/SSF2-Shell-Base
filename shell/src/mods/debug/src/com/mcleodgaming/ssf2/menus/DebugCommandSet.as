package com.mcleodgaming.ssf2.menus
{
    /** Base for console command groups: output and flag parsing go through the owning console. */
    public class DebugCommandSet
    {
        protected var c:ShellDebugConsole;

        public function DebugCommandSet(console:ShellDebugConsole)
        {
            this.c = console;
        }

        public function writeLine(str:String):void
        {
            this.c.writeLine(str);
        }

        public function parseFlags(args:Array):Array
        {
            return this.c.parseFlags(args);
        }
    }
}
