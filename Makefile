# Compile FFmpeg and all its dependencies to JavaScript.
# You need emsdk environment installed and activated, see:
# <https://kripken.github.io/emscripten-site/docs/getting_started/downloads.html>.

PRE_JS = build/pre.js
POST_JS_SYNC = build/post-sync.js
POST_JS_WORKER = build/post-worker.js

COMMON_FILTERS = aresample silenceremove
COMMON_DEMUXERS = wav concat
COMMON_DECODERS = pcm_s16le pcm_u8

WAV_MUXERS = wav null
WAV_ENCODERS = pcm_s16le pcm_u8
FFMPEG_WEBM_BC = build/ffmpeg-webm/ffmpeg.bc

all: wav
wav: ffmpeg-wav.js ffmpeg-worker-wav.js

clean: clean-js clean-wasm \
	clean-opus clean-libvpx clean-ffmpeg-webm \
	clean-lame clean-x264 clean-ffmpeg-mp4
clean-js:
	rm -f ffmpeg*.js
clean-wasm:
	rm -f ffmpeg*.wasm
clean-opus:
	cd build/opus && git clean -xdf
clean-libvpx:
	cd build/libvpx && git clean -xdf
clean-ffmpeg-webm:
	cd build/ffmpeg-webm && git clean -xdf
clean-lame:
	cd build/lame && git clean -xdf
clean-x264:
	cd build/x264 && git clean -xdf
clean-ffmpeg-mp4:
	cd build/ffmpeg-mp4 && git clean -xdf

# TODO(Kagami): Emscripten documentation recommends to always use shared
# libraries but it's not possible in case of ffmpeg because it has
# multiple declarations of `ff_log2_tab` symbol. GCC builds FFmpeg fine
# though because it uses version scripts and so `ff_log2_tag` symbols
# are not exported to the shared libraries. Seems like `emcc` ignores
# them. We need to file bugreport to upstream. See also:
# - <https://kripken.github.io/emscripten-site/docs/compiling/Building-Projects.html>
# - <https://github.com/kripken/emscripten/issues/831>
# - <https://ffmpeg.org/pipermail/libav-user/2013-February/003698.html>
FFMPEG_COMMON_ARGS = \
	--cc=emcc \
	--ranlib=emranlib \
	--enable-cross-compile \
	--target-os=none \
	--arch=x86 \
	--disable-runtime-cpudetect \
	--disable-asm \
	--disable-fast-unaligned \
	--disable-pthreads \
	--disable-w32threads \
	--disable-os2threads \
	--disable-debug \
	--disable-stripping \
	--disable-safe-bitstream-reader \
	\
	--disable-all \
	--enable-ffmpeg \
	--enable-avcodec \
	--enable-avformat \
	--enable-avfilter \
	--enable-swresample \
	--disable-swscale \
	--disable-network \
	--disable-d3d11va \
	--disable-dxva2 \
	--disable-vaapi \
	--disable-vdpau \
	$(addprefix --enable-decoder=,$(COMMON_DECODERS)) \
	$(addprefix --enable-demuxer=,$(COMMON_DEMUXERS)) \
	--enable-protocol=file \
	$(addprefix --enable-filter=,$(COMMON_FILTERS)) \
	--disable-bzlib \
	--disable-iconv \
	--disable-libxcb \
	--disable-lzma \
	--disable-sdl2 \
	--disable-securetransport \
	--disable-xlib \
	--disable-zlib

build/ffmpeg-webm/ffmpeg.bc:
	cd build/ffmpeg-webm && \
	emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		$(addprefix --enable-encoder=,$(WAV_ENCODERS)) \
		$(addprefix --enable-muxer=,$(WAV_MUXERS)) \
		&& \
	emmake make -j && \
	cp ffmpeg ffmpeg.bc

EMCC_COMMON_ARGS = \
	-O3 \
	--closure 1 \
	--memory-init-file 0 \
	-s WASM=1 \
	-s TEXTDECODER=0 \
	-s DYNAMIC_EXECUTION=0 \
	-s WASM_ASYNC_COMPILATION=0 \
	-s ASSERTIONS=0 \
	-s EXIT_RUNTIME=1 \
	-s NODEJS_CATCH_EXIT=0 \
	-s NODEJS_CATCH_REJECTION=0 \
	-s TOTAL_MEMORY=67108864 \
	-lnodefs.js -lworkerfs.js \
	--pre-js $(PRE_JS) \
	-o $@

ffmpeg-wav.js: $(FFMPEG_WEBM_BC) $(PRE_JS) $(POST_JS_SYNC)
	emcc $(FFMPEG_WEBM_BC) \
		--post-js $(POST_JS_SYNC) \
		$(EMCC_COMMON_ARGS)

ffmpeg-worker-wav.js: $(FFMPEG_WEBM_BC) $(PRE_JS) $(POST_JS_WORKER)
	emcc $(FFMPEG_WEBM_BC) \
		--post-js $(POST_JS_WORKER) \
		$(EMCC_COMMON_ARGS)
