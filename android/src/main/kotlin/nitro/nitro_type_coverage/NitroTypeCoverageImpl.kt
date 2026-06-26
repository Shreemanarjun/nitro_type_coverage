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
import nitro.nitro_type_coverage_module.TcNested
import nitro.nitro_type_coverage_module.TcNullableWrapper
import nitro.nitro_type_coverage_module.TcPacket
import nitro.nitro_type_coverage_module.TcEvent
import nitro.nitro_type_coverage_module.TcPoint
import nitro.nitro_type_coverage_module.TcStatus
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

    // ── Nullable primitives ───────────────────────────────────────────────────
    override fun echoNullableInt(value: Long?): Long? = value
    override fun echoNullableDouble(value: Double?): Double? = value
    override fun echoNullableBool(value: Boolean?): Boolean? = value
    override fun echoNullableString(value: String?): String = value ?: ""

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
    @Suppress("UNCHECKED_CAST")
    override suspend fun echoIntList(value: Any?): List<Long> =
        (value as? List<Long>) ?: emptyList()

    @Suppress("UNCHECKED_CAST")
    override suspend fun echoDoubleList(value: Any?): List<Double> =
        (value as? List<Double>) ?: emptyList()

    @Suppress("UNCHECKED_CAST")
    override suspend fun echoStringList(value: Any?): List<String> =
        (value as? List<String>) ?: emptyList()

    @Suppress("UNCHECKED_CAST")
    override suspend fun echoConfigList(values: Any?): List<TcConfig> =
        (values as? List<TcConfig>) ?: emptyList()

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
    override suspend fun echoConfigListSync(values: Any?): List<TcConfig> {
        @Suppress("UNCHECKED_CAST")
        return (values as? List<TcConfig>) ?: emptyList()
    }

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

    // ── Maps (§24) ───────────────────────────────────────────────────────────
    @Suppress("UNCHECKED_CAST")
    override fun echoIntMap(value: Any?): Any? = value
    @Suppress("UNCHECKED_CAST")
    override fun echoStringMap(value: Any?): Any? = value
    @Suppress("UNCHECKED_CAST")
    override fun echoDoubleMap(value: Any?): Any? = value
    @Suppress("UNCHECKED_CAST")
    override fun echoBoolMap(value: Any?): Any? = value

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
    private val _batchIntChannel = Channel<Long>(Channel.UNLIMITED)
    override val batchIntStream: kotlinx.coroutines.flow.Flow<Long> = _batchIntChannel.receiveAsFlow()
    override fun configureBatchStream(from: Long, count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) { _batchIntChannel.send(from + i) }
        }
    }

    private val _batchDoubleChannel = Channel<Double>(Channel.UNLIMITED)
    override val batchDoubleStream: kotlinx.coroutines.flow.Flow<Double> = _batchDoubleChannel.receiveAsFlow()
    @Suppress("UNCHECKED_CAST")
    override fun configureBatchDoubleStream(values: Any?) {
        val list = (values as? List<Double>) ?: return
        CoroutineScope(Dispatchers.Default).launch {
            for (v in list) { _batchDoubleChannel.send(v) }
        }
    }

    private val _batchBoolChannel = Channel<Boolean>(Channel.UNLIMITED)
    override val batchBoolStream: kotlinx.coroutines.flow.Flow<Boolean> = _batchBoolChannel.receiveAsFlow()
    @Suppress("UNCHECKED_CAST")
    override fun configureBatchBoolStream(values: Any?) {
        // Bridge decodes bool items as Long (0L = false, non-zero = true)
        val list = (values as? List<Any>) ?: return
        CoroutineScope(Dispatchers.Default).launch {
            for (v in list) { _batchBoolChannel.send((v as? Long ?: 0L) != 0L) }
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
    @Suppress("UNCHECKED_CAST")
    override suspend fun echoListBool(value: Any?): List<Boolean> {
        val list = value as? List<*> ?: return emptyList()
        return list.map { (it as? Long ?: 0L) != 0L }
    }

    @Suppress("UNCHECKED_CAST")
    override suspend fun echoPointList(values: Any?): List<TcPoint> =
        (values as? List<TcPoint>) ?: emptyList()

    // ── §35: @NitroNativeAsync with typed returns ──────────────────────────────
    override suspend fun nativeAsyncInt(value: Long): Long = value
    override suspend fun nativeAsyncDouble(value: Double): Double = value
    override suspend fun nativeAsyncBool(value: Boolean): Boolean = value
    override suspend fun nativeAsyncString(value: String): String = value

    // ── §35: Stream<String> ───────────────────────────────────────────────────
    private val _stringStream = MutableSharedFlow<String>(extraBufferCapacity = 64)
    override val stringStream: kotlinx.coroutines.flow.Flow<String> = _stringStream
    @Suppress("UNCHECKED_CAST")
    override fun configureStringStream(values: Any?) {
        val list = (values as? List<String>) ?: return
        CoroutineScope(Dispatchers.Default).launch {
            for (v in list) { _stringStream.emit(v) }
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

    // ── §36: @NitroOwned ─────────────────────────────────────────────────────
    // acquireBuffer: allocate a ByteArray of `size` bytes and return its address.
    // The bridge wraps this as a NativeHandle<Void> (opaque pointer).
    override fun acquireBuffer(size: Long): Long {
        // Allocate on Kotlin side; return address via sun.misc.Unsafe or store globally.
        // For testing, we just return a stable non-null Long pointer value.
        val buf = ByteArray(size.toInt())
        // Store in a static list to prevent GC; return index + 1 as "pointer"
        val idx = _ownedBuffers.size.toLong()
        _ownedBuffers.add(buf)
        return idx + 1L  // Non-zero = valid handle
    }

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

    companion object {
        private val _ownedBuffers = mutableListOf<ByteArray>()
    }
}
