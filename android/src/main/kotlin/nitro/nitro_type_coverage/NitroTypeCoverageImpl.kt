package nitro.nitro_type_coverage

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import nitro.nitro_type_coverage_module.HybridNitroTypeCoverageSpec
import nitro.nitro_type_coverage_module.TcConfig
import nitro.nitro_type_coverage_module.TcPoint
import nitro.nitro_type_coverage_module.TcStatus

/// Complete echo implementation of HybridNitroTypeCoverageSpec.
/// Every method returns exactly what it receives.
class NitroTypeCoverageImpl : HybridNitroTypeCoverageSpec {

    // ── Streams ───────────────────────────────────────────────────────────────
    private val _intStream = MutableSharedFlow<Long>(extraBufferCapacity = 64)
    private val _pointStream = MutableSharedFlow<TcPoint>(extraBufferCapacity = 64)
    private val _boolStream = MutableSharedFlow<Boolean>(extraBufferCapacity = 64)
    override val intStream: Flow<Long> = _intStream
    override val pointStream: Flow<TcPoint> = _pointStream
    override val boolStream: Flow<Boolean> = _boolStream

    // ── Properties ────────────────────────────────────────────────────────────
    override var precision: Long = 0L
    override var tag: String = ""
    override var nullableRate: Double? = null
    override var enabled: Boolean = false
    override var currentStatus: TcStatus = TcStatus.OK

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
    override fun echoNullableInt(value: Long?): Long = value ?: -1L
    override fun echoNullableDouble(value: Double?): Double = value ?: Double.NaN
    override fun echoNullableBool(value: Boolean?): Boolean = value ?: false
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
    override suspend fun asyncNullableInt(value: Long?): Long = value ?: -1L
    override suspend fun asyncNullableDouble(value: Double?): Double = value ?: Double.NaN
    override suspend fun asyncNullableBool(value: Boolean?): Boolean = value ?: false
    override suspend fun asyncNullableString(value: String?): String = value ?: ""

    // ── Callback ──────────────────────────────────────────────────────────────
    override fun onIntEvent(callback: (p0: Long) -> Unit) {
        // Fire immediately with a test value so Dart can verify the callback fires
        callback(42L)
    }

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

    // ── Error handling ────────────────────────────────────────────────────────
    override fun throwNative(message: String) {
        throw RuntimeException(message)
    }

    override suspend fun throwNativeAsync(message: String) {
        throw RuntimeException(message)
    }
}
