
SDL_LoadWAV_RW :: (src: *SDL_RWops, freesrc: s32, spec: *SDL_AudioSpec, audio_buf: **u8, audio_len: *u32) -> *SDL_AudioSpec #foreign SDL2;
SDL_LoadWAV :: (file: *u8, spec: *SDL_AudioSpec, audio_buf: **u8, audio_len: *u32) -> *SDL_AudioSpec {
    return SDL_LoadWAV_RW(SDL_RWFromFile(file, "rb"),1, spec,audio_buf,audio_len);
}

Audio_Stream :: struct {
    spec : SDL_AudioSpec;
    len : u32;
    data : *u8;

    load :: (path : string) -> Audio_Stream {
        result : Audio_Stream;
        SDL_LoadWAV(Basic.to_c_string(path), *result.spec, *result.data, *result.len);
        return result;
    }

    unload :: (wav : *Audio_Stream) {
        SDL_FreeWAV(wav.data);
        wav.data = null;

    }

    mix_and_play_immediate :: (stream : *Audio_Stream, volume : s8, device : SDL_AudioDeviceID) {
        SDL_ClearQueuedAudio(context.game.audio_device);
        mixed : *void = Basic.talloc(stream.len);
        memset(mixed, 0, stream.len);
        SDL_MixAudioFormat(mixed, stream.data, AUDIO_S16, stream.len, volume);
        Basic.assert(SDL_QueueAudio(device, mixed, stream.len) == 0);
    }
};

print_audio_spec :: (spec : SDL_AudioSpec) {
    Basic.log("spec: %", spec);
}
