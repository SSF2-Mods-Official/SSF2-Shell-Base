// Decompiled by AS3 Sorcerer 6.78
// www.buraks.com/as3sorcerer

//com.mcleodgaming.ssf2.audio.PitchShiftSound

package com.mcleodgaming.ssf2.audio
{
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.events.SampleDataEvent;
    import flash.utils.ByteArray;
    import flash.media.SoundTransform;

    public class PitchShiftSound 
    {
        private var m_sourceSound:Sound;
        private var m_dynamicSound:Sound;
        private var m_channel:SoundChannel;
        private var m_sampleData:ByteArray;
        private var m_samplePosition:Number;
        private var m_pitchShift:Number;
        private var m_volume:Number;
        private var m_isPlaying:Boolean;
        private var m_totalSamples:int;
        
        public function PitchShiftSound()
        {
            this.m_sourceSound = null;
            this.m_dynamicSound = null;
            this.m_channel = null;
            this.m_sampleData = null;
            this.m_samplePosition = 0;
            this.m_pitchShift = 1.0;
            this.m_volume = 1.0;
            this.m_isPlaying = false;
            this.m_totalSamples = 0;
        }
        
        public function get IsPlaying():Boolean
        {
            return (this.m_isPlaying);
        }
        
        public function get PitchShift():Number
        {
            return (this.m_pitchShift);
        }
        
        public function set PitchShift(value:Number):void
        {
            // Allow deeper slow-downs; clamp between 0.05x and 3x
            this.m_pitchShift = Math.max(0.05, Math.min(3.0, value));
        }
        
        public function get Volume():Number
        {
            return (this.m_volume);
        }
        
        public function set Volume(value:Number):void
        {
            this.m_volume = Math.max(0, Math.min(1, value));
            if (this.m_channel)
            {
                this.m_channel.soundTransform = new SoundTransform(this.m_volume);
            };
        }
        
        /**
         * Load and prepare a sound for pitch-shifted playback
         * @param sound The source Sound object to pitch shift
         */
        public function loadSound(sound:Sound):void
        {
            if (this.m_isPlaying)
            {
                this.stop();
            };
            
            this.m_sourceSound = sound;
            
            // Extract all samples from the source sound
            this.m_sampleData = new ByteArray();
            this.m_totalSamples = this.m_sourceSound.extract(this.m_sampleData, int.MAX_VALUE, 0);
            this.m_sampleData.position = 0;
        }
        
        /**
         * Play the sound with pitch shifting
         * @param pitchShift Initial pitch shift (1.0 = normal, >1.0 = faster/higher, <1.0 = slower/lower)
         * @param volume Volume level (0.0 to 1.0)
         */
        public function play(pitchShift:Number = 1.0, volume:Number = 1.0):void
        {
            if ((!(this.m_sourceSound)) || (!(this.m_sampleData)))
            {
                return;
            };
            
            if (this.m_isPlaying)
            {
                this.stop();
            };
            
            this.m_pitchShift = Math.max(0.05, Math.min(3.0, pitchShift));
            this.m_volume = Math.max(0, Math.min(1, volume));
            this.m_samplePosition = 0;
            
            // Create a new dynamic sound that we'll feed samples to
            this.m_dynamicSound = new Sound();
            this.m_dynamicSound.addEventListener(SampleDataEvent.SAMPLE_DATA, this.onSampleData);
            
            // Start playing
            this.m_channel = this.m_dynamicSound.play(0, 0, new SoundTransform(this.m_volume));
            this.m_isPlaying = true;
        }
        
        /**
         * Stop playback
         */
        public function stop():void
        {
            if (this.m_channel)
            {
                this.m_channel.stop();
                this.m_channel = null;
            };
            
            if (this.m_dynamicSound)
            {
                this.m_dynamicSound.removeEventListener(SampleDataEvent.SAMPLE_DATA, this.onSampleData);
                this.m_dynamicSound = null;
            };
            
            this.m_isPlaying = false;
        }
        
        /**
         * Sample data event handler - this is where the pitch shifting magic happens
         */
        private function onSampleData(event:SampleDataEvent):void
        {
            const BUFFER_SIZE:int = 8192; // Number of samples to write per callback
            var samplesWritten:int = 0;
            
            while (samplesWritten < BUFFER_SIZE)
            {
                // Calculate the actual position in the source samples based on pitch shift
                var sourceIndex:int = int(this.m_samplePosition);
                
                // Check if we've reached the end of the sound
                if ((sourceIndex * 8) >= this.m_sampleData.length)
                {
                    // End of sound reached, write silence to finish cleanly
                    while (samplesWritten < BUFFER_SIZE)
                    {
                        event.data.writeFloat(0);
                        event.data.writeFloat(0);
                        samplesWritten++;
                    };
                    this.stop();
                    return;
                };
                
                // Read the sample from source data (stereo = 2 floats per sample)
                this.m_sampleData.position = sourceIndex * 8; // 8 bytes per stereo sample (4 bytes per float * 2 channels)
                
                var leftSample:Number = 0;
                var rightSample:Number = 0;
                
                if (this.m_sampleData.bytesAvailable >= 8)
                {
                    leftSample = this.m_sampleData.readFloat();
                    rightSample = this.m_sampleData.readFloat();
                    
                    // Optional: Linear interpolation for smoother quality
                    // (only if we're not at the last sample)
                    if ((this.m_samplePosition % 1 != 0) && (this.m_sampleData.bytesAvailable >= 8))
                    {
                        var nextLeft:Number = this.m_sampleData.readFloat();
                        var nextRight:Number = this.m_sampleData.readFloat();
                        var fraction:Number = this.m_samplePosition % 1;
                        
                        leftSample = leftSample + (nextLeft - leftSample) * fraction;
                        rightSample = rightSample + (nextRight - rightSample) * fraction;
                    };
                };
                
                // Write the sample to output
                event.data.writeFloat(leftSample);
                event.data.writeFloat(rightSample);
                
                // Advance position by pitch shift amount
                // Higher pitch = read through samples faster
                // Lower pitch = read through samples slower
                this.m_samplePosition += this.m_pitchShift;
                
                samplesWritten++;
            };
        }
    }
}//package com.mcleodgaming.ssf2.audio
