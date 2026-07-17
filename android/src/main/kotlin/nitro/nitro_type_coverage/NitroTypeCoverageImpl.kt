package nitro.nitro_type_coverage

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import nitro.nitro_type_coverage_module.HybridNitroTypeCoverageSpec
import nitro.nitro_type_coverage_module.NitroNullableBool
import nitro.nitro_type_coverage_module.NitroNullableDouble
import nitro.nitro_type_coverage_module.NitroNullableInt
import nitro.nitro_type_coverage_module.TcConfig
import nitro.nitro_type_coverage_module.TcDataRecord
import nitro.nitro_type_coverage_module.TcMeta
import nitro.nitro_type_coverage_module.TcDeepRecord
import nitro.nitro_type_coverage_module.TcNested
import nitro.nitro_type_coverage_module.TcNullableWrapper
import nitro.nitro_type_coverage_module.TcPacket
import nitro.nitro_type_coverage_module.TcEvent
import nitro.nitro_type_coverage_module.TcPoint
import nitro.nitro_type_coverage_module.TcStatus
import nitro.nitro_type_coverage_module.TcPriority
import nitro.nitro_type_coverage_module.TcStructHolder

/// Complete echo implementation of HybridNitroTypeCoverageSpec.
/// Every method returns exactly what it receives.
class NitroTypeCoverageImpl : HybridNitroTypeCoverageSpec {

    // ── Streams ───────────────────────────────────────────────────────────────
    private val _intStream = MutableSharedFlow<Long>(extraBufferCapacity = 64)
    private val _pointStream = MutableSharedFlow<TcPoint>(extraBufferCapacity = 64)
    private val _boolStream = MutableSharedFlow<Boolean>(extraBufferCapacity = 64)
    private val _doubleStream = MutableSharedFlow<Double>(extraBufferCapacity = 64)
    private val _statusStream = MutableSharedFlow<TcStatus>(extraBufferCapacity = 64)
    override val intStream: Flow<Long> = _intStream
    override val pointStream: Flow<TcPoint> = _pointStream
    override val boolStream: Flow<Boolean> = _boolStream
    override val doubleStream: Flow<Double> = _doubleStream
    override val statusStream: Flow<TcStatus> = _statusStream

    // ── Properties ────────────────────────────────────────────────────────────
    override var precision: Long = 0L
    override var tag: String = ""
    override var nullableRate: Double? = null
    override var enabled: Boolean = false
    override var currentStatus: TcStatus = TcStatus.OK
    override var nullableCounter: Long? = null
    override var optionalFlag: Boolean? = null

    // ── Primitives ────────────────────────────────────────────────────────────
    override fun echoInt(value: Long): Long = value
    override fun echoDouble(value: Double): Double = value
    override fun echoBool(value: Boolean): Boolean = value
    override fun echoString(value: String): String = value

    // ── Multi-param ───────────────────────────────────────────────────────────
    override fun addInts(a: Long, b: Long, c: Long): Long = a + b + c
    override fun mulDoubles(a: Double, b: Double): Double = a * b
    override fun joinStrings(a: String, b: String, separator: String): String = a + separator + b

    // ── DateTime ─────────────────────────────────────────────────────────────
    override fun echoDateTime(value: Long): Long = value
    override fun echoNullableDateTime(value: Long?): Long? = value

    // ── Nullable primitives ───────────────────────────────────────────────────
    override fun echoNullableInt(value: Long?): Long? = value
    override fun echoNullableDouble(value: Double?): Double? = value
    override fun echoNullableBool(value: Boolean?): Boolean? = value
    override fun echoNullableString(value: String?): String? = value

    // ── Enum ──────────────────────────────────────────────────────────────────
    override fun echoStatus(value: TcStatus): TcStatus = value
    // Must return TcStatus? (nullable) so the bridge encodes null as -1L sentinel
    override fun echoNullableStatus(value: TcStatus?): TcStatus? = value

    // ── Struct ────────────────────────────────────────────────────────────────
    override fun echoPoint(value: TcPoint): TcPoint = value

    // ── @HybridRecord ─────────────────────────────────────────────────────────
    override fun echoConfig(value: TcConfig): TcConfig = value

    // ── TypedData (zero-copy via DirectByteBuffer) ────────────────────────────
    private fun <T> toDirectBuffer(data: T, put: (java.nio.ByteBuffer) -> Unit, size: Int): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(size).order(java.nio.ByteOrder.nativeOrder())
        put(buf)
        buf.rewind()
        return buf
    }

    override fun echoBytes(value: ByteArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size)
        buf.put(value); buf.flip(); return buf
    }

    override fun echoFloats(value: FloatArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size * 4).order(java.nio.ByteOrder.nativeOrder())
        buf.asFloatBuffer().put(value); buf.rewind(); return buf
    }

    override fun echoFloat64s(value: DoubleArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size * 8).order(java.nio.ByteOrder.nativeOrder())
        buf.asDoubleBuffer().put(value); buf.rewind(); return buf
    }

    override fun echoInt8s(value: ByteArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size)
        buf.put(value); buf.flip(); return buf
    }
    override fun echoInt16s(value: ShortArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size * 2).order(java.nio.ByteOrder.nativeOrder())
        buf.asShortBuffer().put(value); buf.rewind(); return buf
    }
    override fun echoInt64s(value: LongArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size * 8).order(java.nio.ByteOrder.nativeOrder())
        buf.asLongBuffer().put(value); buf.rewind(); return buf
    }
    override fun echoInt32s(value: IntArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size * 4).order(java.nio.ByteOrder.nativeOrder())
        buf.asIntBuffer().put(value); buf.rewind(); return buf
    }

    // ── Lists (async) ─────────────────────────────────────────────────────────
    override suspend fun echoIntList(value: List<Long>): List<Long> = value

    override suspend fun echoDoubleList(value: List<Double>): List<Double> = value

    override suspend fun echoStringList(value: List<String>): List<String> = value

    override suspend fun echoConfigList(values: List<TcConfig>): List<TcConfig> = values

    // ── Async ─────────────────────────────────────────────────────────────────
    override suspend fun asyncInt(value: Long): Long = value
    override suspend fun asyncDouble(value: Double): Double = value
    override suspend fun asyncBool(value: Boolean): Boolean = value
    override suspend fun asyncString(value: String): String = value
    override suspend fun asyncConfig(value: TcConfig): TcConfig = value

    // ── Async nullable ────────────────────────────────────────────────────────
    override suspend fun asyncNullableInt(value: Long?): Long? = value
    override suspend fun asyncNullableDouble(value: Double?): Double? = value
    override suspend fun asyncNullableBool(value: Boolean?): Boolean? = value
    override suspend fun asyncNullableString(value: String?): String = value ?: ""

    // ── Async additions ───────────────────────────────────────────────────────
    override suspend fun asyncPoint(value: TcPoint): TcPoint = value
    override suspend fun asyncNullableStatus(value: TcStatus?): TcStatus? = value
    override suspend fun asyncMeta(value: TcMeta): TcMeta = value

    // ── @HybridRecord (TcMeta) ────────────────────────────────────────────────
    override fun echoMeta(value: TcMeta): TcMeta = value

    // ── @HybridRecord with TypedData fields (§29) ────────────────────────────
    override fun echoDataRecord(value: TcDataRecord): TcDataRecord = value

    // ── §30: 6 new type coverage features ─────────────────────────────────────

    // #1 Stream<TcConfig>
    private val _configStream = MutableSharedFlow<TcConfig>(extraBufferCapacity = 64)
    override val configStream: kotlinx.coroutines.flow.Flow<TcConfig> = _configStream
    override fun configureConfigStream(seed: TcConfig, count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                _configStream.emit(TcConfig(
                    name = "${seed.name}-$i", count = seed.count + i,
                    enabled = seed.enabled, threshold = seed.threshold + i * 0.1))
            }
        }
    }

    // #2 Nullable @HybridRecord
    override fun echoNullableConfig(value: TcConfig?): TcConfig? = value

    // #3 Nested @HybridRecord
    override fun echoNested(value: TcNested): TcNested = value

    // #4 List<TcConfig> sync param
    override suspend fun echoConfigListSync(values: List<TcConfig>): List<TcConfig> = values

    // #5 NitroNullable inside @HybridRecord
    override fun echoNullableWrapper(value: TcNullableWrapper): TcNullableWrapper = value

    // #6 Bidirectional callback — call Dart and get the transformed value
    override fun onTransformEvent(transformCb: (p0: Long) -> Long) {
        @Suppress("UNUSED_VARIABLE")
        val result = transformCb(42L)
    }

    // ── NitroNullable built-in types (from package:nitro) ────────────────────
    override fun echoNullableIntSafe(value: NitroNullableInt): NitroNullableInt = value
    override fun echoNullableDoubleSafe(value: NitroNullableDouble): NitroNullableDouble = value
    override fun echoNullableBoolSafe(value: NitroNullableBool): NitroNullableBool = value

    // ── Maps (§24 + L4) ─────────────────────────────────────────────────────
    override fun echoIntMap(value: Map<String, Long>): Map<String, Long> = value
    override fun echoStringMap(value: Map<String, String>): Map<String, String> = value
    override fun echoDoubleMap(value: Map<String, Double>): Map<String, Double> = value
    override fun echoBoolMap(value: Map<String, Boolean>): Map<String, Boolean> = value
    override fun echoConfigMap(value: Map<String, TcConfig>): Map<String, TcConfig> = value
    override fun echoEventMap(value: Map<String, TcEvent>): Map<String, TcEvent> = value

    // ── @HybridRecord with enum field (§25) ───────────────────────────────────
    override fun echoPacket(value: TcPacket): TcPacket = value

    // ── Nullable struct (§26) ─────────────────────────────────────────────────
    override fun echoNullablePoint(value: TcPoint?): TcPoint? = value

    // ── #5: @HybridStruct in @HybridRecord (§32) ──────────────────────────────
    override fun echoStructHolder(value: TcStructHolder): TcStructHolder = value

    // ── #4: Bidirectional callbacks with non-int returns (§32) ───────────────
    override fun onStringTransform(stringCb: (p0: Long) -> String) {
        @Suppress("UNUSED_VARIABLE")
        val result = stringCb(42L)  // Dart returns "transformed_42" or similar
    }
    override fun onDoubleTransform(doubleCb: (p0: Long) -> Double) {
        @Suppress("UNUSED_VARIABLE")
        val result = doubleCb(7L)  // Dart returns 7.0 * 1.5 = 10.5 or similar
    }

    // ── #9: Batch stream (§32) ─────────────────────────────────────────────────
    // Channel.UNLIMITED buffers all emitted items unconditionally, so items
    // are never dropped even when the bridge collector hasn't subscribed yet.
    //
    // Each configure starts a FRESH sequence (§38 re-subscribe contract):
    // cancel a previous sender that may still be running and drain leftovers
    // that a mid-flush cancel left queued in the app-lifetime channel —
    // otherwise stale items cascade into the next subscription's values
    // (seen as §38 failures on slow emulators).
    private val _batchIntChannel = Channel<Long>(Channel.UNLIMITED)
    private var _batchIntJob: kotlinx.coroutines.Job? = null
    override val batchIntStream: kotlinx.coroutines.flow.Flow<Long> = _batchIntChannel.receiveAsFlow()
    override fun configureBatchStream(from: Long, count: Long) {
        _batchIntJob?.cancel()
        while (_batchIntChannel.tryReceive().isSuccess) { }
        _batchIntJob = CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) { _batchIntChannel.send(from + i) }
        }
    }

    private val _batchDoubleChannel = Channel<Double>(Channel.UNLIMITED)
    private var _batchDoubleJob: kotlinx.coroutines.Job? = null
    override val batchDoubleStream: kotlinx.coroutines.flow.Flow<Double> = _batchDoubleChannel.receiveAsFlow()
    override fun configureBatchDoubleStream(values: List<Double>) {
        _batchDoubleJob?.cancel()
        while (_batchDoubleChannel.tryReceive().isSuccess) { }
        _batchDoubleJob = CoroutineScope(Dispatchers.Default).launch {
            for (v in values) { _batchDoubleChannel.send(v) }
        }
    }

    private val _batchBoolChannel = Channel<Boolean>(Channel.UNLIMITED)
    private var _batchBoolJob: kotlinx.coroutines.Job? = null
    override val batchBoolStream: kotlinx.coroutines.flow.Flow<Boolean> = _batchBoolChannel.receiveAsFlow()
    override fun configureBatchBoolStream(values: List<Boolean>) {
        _batchBoolJob?.cancel()
        while (_batchBoolChannel.tryReceive().isSuccess) { }
        _batchBoolJob = CoroutineScope(Dispatchers.Default).launch {
            for (v in values) { _batchBoolChannel.send(v) }
        }
    }

    // ── §35: Bool/enum bidirectional callbacks ─────────────────────────────────
    override fun onBoolTransform(boolCb: (p0: Long) -> Boolean) {
        @Suppress("UNUSED_VARIABLE")
        val result = boolCb(42L)  // Dart returns true/false based on value
    }
    override fun onStatusTransform(statusCb: (p0: Long) -> TcStatus) {
        @Suppress("UNUSED_VARIABLE")
        val result = statusCb(42L)  // Dart returns TcStatus based on value
    }

    // ── §35: List<bool> and List<TcPoint> ────────────────────────────────────
    override suspend fun echoListBool(value: List<Boolean>): List<Boolean> = value

    override suspend fun echoPointList(values: List<TcPoint>): List<TcPoint> = values

    // ── §35: @NitroNativeAsync with typed returns ──────────────────────────────
    override suspend fun nativeAsyncInt(value: Long): Long = value
    override suspend fun nativeAsyncDouble(value: Double): Double = value
    override suspend fun nativeAsyncBool(value: Boolean): Boolean = value
    override suspend fun nativeAsyncString(value: String): String = value

    // ── §35: Stream<String> ───────────────────────────────────────────────────
    private val _stringStream = MutableSharedFlow<String>(extraBufferCapacity = 64)
    override val stringStream: kotlinx.coroutines.flow.Flow<String> = _stringStream
    override fun configureStringStream(values: List<String>) {
        CoroutineScope(Dispatchers.Default).launch {
            for (v in values) { _stringStream.emit(v) }
        }
    }

    // ── §42: Batch Stream<String> ─────────────────────────────────────────────
    private val _batchStringStream = MutableSharedFlow<String>(extraBufferCapacity = 64)
    override val batchStringStream: kotlinx.coroutines.flow.Flow<String> = _batchStringStream
    override fun configureBatchStringStream(values: List<String>) {
        CoroutineScope(Dispatchers.Default).launch {
            for (v in values) { _batchStringStream.emit(v) }
        }
    }

    // ── §35: Backpressure.block stream ────────────────────────────────────────
    private val _blockIntStream = MutableSharedFlow<Long>(extraBufferCapacity = 64)
    override val blockIntStream: kotlinx.coroutines.flow.Flow<Long> = _blockIntStream
    override fun configureBlockIntStream(from: Long, count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) { _blockIntStream.emit(from + i) }
        }
    }

    // ── Callbacks with struct and multi-params (§27) ──────────────────────────
    override fun onPointEvent(pointCb: (p0: TcPoint) -> Unit) {
        pointCb(TcPoint(x = 1.0, y = 2.0, z = 3.0))
    }
    override fun onDetailEvent(detailCb: (p0: Long, p1: Double) -> Unit) {
        detailCb(42L, 9.81)
    }

    // ── Callback ──────────────────────────────────────────────────────────────
    override fun onIntEvent(callback: (p0: Long) -> Unit) {
        // Fire immediately with a test value so Dart can verify the callback fires
        callback(42L)
    }
    override fun onBoolEvent(boolCb: (p0: Boolean) -> Unit) { boolCb(true) }
    override fun onDoubleEvent(doubleCb: (p0: Double) -> Unit) { doubleCb(2.71828) }

    // ── Stream control ────────────────────────────────────────────────────────
    override fun configureStream(from: Long, count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                val v = from + i
                _intStream.emit(v)
                _pointStream.emit(TcPoint(x = v.toDouble(), y = v.toDouble() * 0.5, z = 0.0))
                _boolStream.emit(v % 2 == 0L)
            }
        }
    }
    override fun configureDoubleStream(start: Double, count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) { _doubleStream.emit(start + i.toDouble()) }
        }
    }
    override fun configureStatusStream(count: Long) {
        val statuses = listOf(TcStatus.OK, TcStatus.ERROR, TcStatus.PENDING)
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) { _statusStream.emit(statuses[(i % 3).toInt()]) }
        }
    }

    // ── Error handling ────────────────────────────────────────────────────────
    override fun throwNative(message: String) {
        throw RuntimeException(message)
    }

    override suspend fun throwNativeAsync(message: String) {
        throw RuntimeException(message)
    }

    override suspend fun throwNativeNativeAsync(message: String) {
        throw RuntimeException(message)
    }

    // ── §70: desktop C-bridge fixes (GitHub #9) ───────────────────────────────
    override fun getConfigOrFail(shouldFail: Boolean): TcConfig {
        if (shouldFail) throw RuntimeException("getConfigOrFail: shouldFail was true")
        return TcConfig(name = "desktop-fix", count = 9, enabled = true, threshold = 1.5)
    }

    override suspend fun nativeAsyncEchoOptionalConfig(config: TcConfig?): TcConfig? = config

    // ── §36: @NitroOwned ─────────────────────────────────────────────────────
    // acquireBuffer: allocate `size` bytes on the native heap and return the address.
    // ART's Unsafe.allocateMemory calls malloc internally, so the C bridge _release
    // function can free() it directly when the NativeHandle is GC'd.
    override fun acquireBuffer(size: Long): Long = _allocNative(size)

    // ── §36: @NitroVariant ────────────────────────────────────────────────────
    override fun echoEvent(event: TcEvent): TcEvent = event

    // ── §36: @NitroResult ─────────────────────────────────────────────────────
    override fun safeDiv(a: Double, b: Double): Double {
        if (b == 0.0) throw ArithmeticException("division by zero")
        return a / b
    }

    override fun validateLabel(label: String): String {
        val trimmed = label.trim()
        if (trimmed.isEmpty()) throw IllegalArgumentException("empty label")
        return trimmed
    }

    // ── §47: Slow async — deliberate delay for timeout testing ────────────────
    override suspend fun slowAsync(delayMs: Long): Long {
        kotlinx.coroutines.delay(delayMs)
        return delayMs
    }

    // ── §52: Deeply nested @HybridRecord ─────────────────────────────────────
    override fun echoDeepRecord(value: TcDeepRecord): TcDeepRecord = value
    override suspend fun asyncDeepRecord(value: TcDeepRecord): TcDeepRecord = value

    // ── §37: @nitroAsync + @NitroOwned/@NitroVariant/@NitroResult ────────────
    override suspend fun asyncAcquireBuffer(size: Long): Long = _allocNative(size)

    override suspend fun asyncEchoEvent(event: TcEvent): TcEvent = event

    override suspend fun asyncSafeDiv(a: Double, b: Double): Double {
        if (b == 0.0) throw ArithmeticException("division by zero")
        return a / b
    }

    override suspend fun asyncValidateLabel(label: String): String {
        val trimmed = label.trim()
        if (trimmed.isEmpty()) throw IllegalArgumentException("empty label")
        return trimmed
    }

    // ── §59: Gap 9 — non-contiguous enum round-trip ───────────────────────────
    override fun echoPriority(value: TcPriority): TcPriority = value

    // ── §60: Gap 10 — Backpressure.bufferDrop stream ─────────────────────────
    private val _bufferDropIntStream = MutableSharedFlow<Long>(extraBufferCapacity = 64)
    override val bufferDropIntStream: kotlinx.coroutines.flow.Flow<Long> = _bufferDropIntStream
    override fun configureBufferDropIntStream(from: Long, count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) { _bufferDropIntStream.emit(from + i) }
        }
    }

    // ── §61: Gap 13 — @NitroVariant as callback parameter ────────────────────
    override fun onEventCallback(handler: (p0: TcEvent) -> Unit) {
        handler(TcEvent.TcEventTap(x = 10L, y = 20L))
        handler(TcEvent.TcEventScroll(delta = 1.5))
    }

    // ── §62: Gap 17 — @NitroVariant as Stream item ───────────────────────────
    private val _eventStream = MutableSharedFlow<TcEvent>(extraBufferCapacity = 64)
    override val eventStream: kotlinx.coroutines.flow.Flow<TcEvent> = _eventStream
    override fun configureEventStream(count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                if (i % 2 == 0L) {
                    _eventStream.emit(TcEvent.TcEventTap(x = i, y = i * 2))
                } else {
                    _eventStream.emit(TcEvent.TcEventScroll(delta = i.toDouble()))
                }
            }
        }
    }

    // ── §63: List<@HybridEnum> ────────────────────────────────────────────────
    override fun getStatusList(): List<TcStatus> = listOf(TcStatus.OK, TcStatus.ERROR, TcStatus.PENDING)
    override fun echoStatusList(values: List<TcStatus>): List<TcStatus> = values

    // ── §64: List<@NitroVariant> ──────────────────────────────────────────────
    override fun getEventList(): List<TcEvent> = listOf(
        TcEvent.TcEventTap(x = 1L, y = 2L),
        TcEvent.TcEventScroll(delta = 3.5),
        TcEvent.TcEventResize(width = 100L, height = 200L),
    )
    override fun echoEventList(values: List<TcEvent>): List<TcEvent> = values

    // ── §65: @NitroVariant as property type ──────────────────────────────────
    override var currentEvent: TcEvent = TcEvent.TcEventTap(x = 0, y = 0)

    // ── §66: Nullable enum/String stream items ────────────────────────────────
    private val _nullableStatusStream = MutableSharedFlow<TcStatus?>(extraBufferCapacity = 64)
    override val nullableStatusStream: kotlinx.coroutines.flow.Flow<TcStatus?> = _nullableStatusStream
    override fun configureNullableStatusStream(count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                if (i % 3L == 0L) _nullableStatusStream.emit(null)
                else when (i % 3L) {
                    1L -> _nullableStatusStream.emit(TcStatus.OK)
                    else -> _nullableStatusStream.emit(TcStatus.ERROR)
                }
            }
        }
    }

    private val _nullableStringStream = MutableSharedFlow<String?>(extraBufferCapacity = 64)
    override val nullableStringStream: kotlinx.coroutines.flow.Flow<String?> = _nullableStringStream
    override fun configureNullableStringStream(count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                _nullableStringStream.emit(if (i % 2L == 0L) null else "item$i")
            }
        }
    }

    // ── L12: @NitroTuple round-trip ───────────────────────────────────────────
    override fun echoPair(value: nitro.nitro_type_coverage_module.TcPair): nitro.nitro_type_coverage_module.TcPair = value
    override fun echoNullablePair(value: nitro.nitro_type_coverage_module.TcPair?): nitro.nitro_type_coverage_module.TcPair? = value

    // ── L13: uint64 round-trip ────────────────────────────────────────────────
    override fun echoUint64(value: Long): Long = value
    override fun echoNullableUint64(value: Long?): Long? = value

    // ── L13: uint64 streams ───────────────────────────────────────────────────
    private val _uint64Stream = MutableSharedFlow<Long>(extraBufferCapacity = 64)
    override val uint64Stream: kotlinx.coroutines.flow.Flow<Long> = _uint64Stream
    override fun configureUint64Stream(from: Long, count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) { _uint64Stream.emit(from + i) }
        }
    }

    private val _nullableUint64Stream = MutableSharedFlow<Long?>(extraBufferCapacity = 64)
    override val nullableUint64Stream: kotlinx.coroutines.flow.Flow<Long?> = _nullableUint64Stream
    override fun configureNullableUint64Stream(count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                _nullableUint64Stream.emit(if (i % 2L == 0L) null else i)
            }
        }
    }

    // ── N1: Narrow scalar types (bridge always uses widest type; typedef aliases are transparent) ───
    override fun echoInt8(value: Long): Long = value
    override fun echoInt16(value: Long): Long = value
    override fun echoInt32(value: Long): Long = value
    override fun echoUint8(value: Long): Long = value
    override fun echoUint16(value: Long): Long = value
    override fun echoUint32(value: Long): Long = value
    override fun echoFloat(value: Double): Double = value
    override fun echoNullableInt32(value: Long?): Long? = value
    override fun echoNullableFloat(value: Double?): Double? = value

    // ── N2: Nullable primitive streams ────────────────────────────────────────
    private val _nullableIntStream = MutableSharedFlow<Long?>(extraBufferCapacity = 64)
    override val nullableIntStream: kotlinx.coroutines.flow.Flow<Long?> = _nullableIntStream
    override fun configureNullableIntStream(count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                _nullableIntStream.emit(if (i % 2L == 0L) null else i)
            }
        }
    }

    private val _nullableDoubleStream = MutableSharedFlow<Double?>(extraBufferCapacity = 64)
    override val nullableDoubleStream: kotlinx.coroutines.flow.Flow<Double?> = _nullableDoubleStream
    override fun configureNullableDoubleStream(count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                _nullableDoubleStream.emit(if (i % 2L == 0L) null else i.toDouble() * 0.5)
            }
        }
    }

    private val _nullableBoolStream = MutableSharedFlow<Boolean?>(extraBufferCapacity = 64)
    override val nullableBoolStream: kotlinx.coroutines.flow.Flow<Boolean?> = _nullableBoolStream
    override fun configureNullableBoolStream(count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                val v: Boolean? = when (i % 3L) {
                    0L -> null
                    1L -> true
                    else -> false
                }
                _nullableBoolStream.emit(v)
            }
        }
    }

    // ── N3: @NitroNativeAsync with nullable returns ───────────────────────────
    override suspend fun nativeAsyncNullableInt(value: Long?): Long? = value
    override suspend fun nativeAsyncNullableDouble(value: Double?): Double? = value
    override suspend fun nativeAsyncNullableBool(value: Boolean?): Boolean? = value

    // ── §67: @NitroNativeAsync param-decoding + return-dispatch coverage ─────
    override suspend fun nativeAsyncStatus(value: TcStatus): TcStatus = value
    override suspend fun nativeAsyncNullableStatus(value: TcStatus?): TcStatus? = value
    override suspend fun nativeAsyncConfig(value: TcConfig): TcConfig = value
    override suspend fun nativeAsyncNullableConfig(value: TcConfig?): TcConfig? = value
    override suspend fun nativeAsyncEvent(value: TcEvent): TcEvent = value
    override suspend fun nativeAsyncConfigList(values: List<TcConfig>): List<TcConfig> = values
    override suspend fun nativeAsyncStatusList(values: List<TcStatus>): List<TcStatus> = values
    override suspend fun nativeAsyncEventList(values: List<TcEvent>): List<TcEvent> = values
    override suspend fun nativeAsyncIntList(values: List<Long>): List<Long> = values
    override suspend fun nativeAsyncWithCallback(value: Long, callback: (Long) -> Unit): Long {
        callback(value)
        return value * 2
    }
    override suspend fun nativeAsyncCounts(seed: Long): Map<String, Long> = mapOf("a" to seed, "b" to seed * 2)
    override suspend fun nativeAsyncNullableUint64(value: Long?): Long? = value

    // ── §68: @NitroNativeAsync — Map/AnyMap params, struct returns, AnyMap ───
    override suspend fun nativeAsyncEchoIntMap(value: Map<String, Long>): Map<String, Long> = value
    override suspend fun nativeAsyncEchoPoint(value: TcPoint): TcPoint = value
    override suspend fun nativeAsyncEchoAnyMap(value: Map<String, Any?>): Map<String, Any?> = value

    companion object {
        // ART's Unsafe.allocateMemory/freeMemory wrap malloc/free, so pointers
        // returned here are freed by the C bridge's _release function via free().
        // Access via reflection to avoid direct sun.misc.Unsafe reference which is
        // flagged by the Kotlin compiler's strict class-path checking on newer AGP.
        private val _unsafeInstance: Any by lazy {
            Class.forName("sun.misc.Unsafe")
                .getDeclaredField("theUnsafe")
                .also { it.isAccessible = true }
                .get(null)!!
        }
        private val _allocateMemoryMethod by lazy {
            Class.forName("sun.misc.Unsafe").getDeclaredMethod("allocateMemory", Long::class.java)
        }
        fun _allocNative(size: Long): Long = _allocateMemoryMethod.invoke(_unsafeInstance, size) as Long
    }
}
