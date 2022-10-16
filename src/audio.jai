
SDL_LoadWAV_RW :: (src: *SDL_RWops, freesrc: s32, spec: *SDL_AudioSpec, audio_buf: **u8, audio_len: *u32) -> *SDL_AudioSpec #foreign SDL2;
SDL_LoadWAV :: (file: *u8, spec: *SDL_AudioSpec, audio_buf: **u8, audio_len: *u32) -> *SDL_AudioSpec {
    return SDL_LoadWAV_RW(SDL_RWFromFile(file, "rb"),1, spec,audio_buf,audio_len);
}

FX_CHANNEL :: 0;
BGM_CHANNEL :: 1;

Audio_Channel :: struct {
    stream: *Audio_Stream;
    position: u32; // Position in stream
    volume: s32 = 32;
    flags : enum_flags { 
        LOOP;
        STOPPED;
    } = .STOPPED;

    mix_to :: (self: *Audio_Channel, dst: *u8, len: u32) {
        if self.flags & .STOPPED then return;
        if self.stream == null then return;

        len_left := len;
        while (true) {
            copy_len : u32 = xx Basic.min(len_left, self.stream.len - self.position);
            SDL_MixAudio(dst, self.stream.data + self.position, copy_len, self.volume);
            self.position += copy_len;
            dst += copy_len;
            len_left -= copy_len;

            if len_left <= 0 then break; // Buffer isn't finished
            
            self.position = 0; // Move playhead to the start
            
            if !(self.flags & .LOOP) { // Stop if we're not looping
                self.flags |= .STOPPED;
                break; 
            }
        }
    }
}

Audio_System :: struct {
    spec : SDL_AudioSpec;
    channels : [2]Audio_Channel;

    init :: (self: *Audio_System) {
        requested_spec := SDL_AudioSpec.{
            freq = 44100,
            format = AUDIO_S32,
            channels = 1,
            silence = 0,
            samples = 4096,
            size = 0,
            callback = audio_callback,
        };
        requested_spec.userdata = self;
        obtained : SDL_AudioSpec = ---;
        success := SDL_OpenAudio(*requested_spec, *self.spec);
        Basic.assert(success == 0);
        Basic.log("Successfully opened audio: %", obtained);
        SDL_PauseAudio(0);
    }

    deinit :: (self: *Audio_System) {
        SDL_CloseAudio();
    }

    audio_callback :: (data: *void, stream: *u8, len: s32) #c_call {
        using self := cast(*Audio_System)data;
        new_context: Context;
        push_context new_context {
            memset(stream, 0, len);
            for *chan: channels { // Onii chan
                Audio_Channel.mix_to(chan, stream, xx len);
            }
        }
    }

    play :: (self: *Audio_System, channel: u32, stream: *Audio_Stream, loop : bool = false) {
        self.channels[channel].stream = stream;
        self.channels[channel].position = 0;
        self.channels[channel].flags = 0;
        if loop {
            self.channels[channel].flags |= .LOOP;
        }
    }

    play_if_not_playing :: (self: *Audio_System, channel: u32, stream: *Audio_Stream) {
        if self.channels[channel].stream == stream then return;

        self.channels[channel].stream = stream;
        self.channels[channel].position = 0;
        self.channels[channel].flags = 0;
        self.channels[channel].flags |= .LOOP;
    }
    
    stop :: (self: *Audio_System, channel: u32) {
        self.channels[channel].flags |= .STOPPED;
    }
}

Audio_Stream :: struct {
    data : *u8;
    len : u32;
    
    /// Load and convert the wav file at path to the requested_spec
    load :: (path : string, requested_spec: SDL_AudioSpec) -> Audio_Stream {
        loaded_data: *u8;
        loaded_len: u32;
        loaded_spec: SDL_AudioSpec = ---;
        SDL_LoadWAV(Basic.to_c_string(path), *loaded_spec, *loaded_data, *loaded_len);
        defer SDL_FreeWAV(loaded_data);

        Basic.log("Loaded %.\nLen: %\nSpec: %", path, loaded_len, loaded_spec);

        cvt : SDL_AudioCVT;
        result := SDL_BuildAudioCVT(*cvt, loaded_spec.format, loaded_spec.channels, loaded_spec.freq,
            requested_spec.format, requested_spec.channels, requested_spec.freq);
        Basic.assert(result >= 0, "Unable to prepare conversion of file %. SDL_Error: %", path, to_string(SDL_GetError()));

        if result == 0 { // Conversion isn't needed
            Basic.log("No need to convert.", path);
            stream : Audio_Stream = ---;
            stream.len = loaded_len;
            // Alloc with our own allocator just in case SDL does something weird with its allocations
            stream.data = Basic.alloc(stream.len);
            memcpy(stream.data, loaded_data, loaded_len); 
            return stream;
        }
        Basic.assert(cvt.needed == 1, "Convertion of % is not possible.", path);
        cvt.len = xx loaded_len;
        cvt.buf = Basic.talloc(cvt.len * cvt.len_mult);
        memcpy(cvt.buf, loaded_data, loaded_len);
        result = SDL_ConvertAudio(*cvt);
        Basic.assert(result == 0, "Unable to convert %.\nSDL_Error: %", path, to_string(SDL_GetError()));

        stream : Audio_Stream = ---;
        stream.len = xx cvt.len_cvt;
        stream.data = Basic.alloc(stream.len);
        memcpy(stream.data, cvt.buf, stream.len);
        
        return stream;
    }

    unload :: (stream : *Audio_Stream) {
        Basic.free(stream.data);
    }
};

