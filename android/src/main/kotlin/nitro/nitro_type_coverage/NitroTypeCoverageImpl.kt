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

/// Echo implementation of HybridNitroTypeCoverageSpec.
/// Every method returns exactly what it receives.
class NitroTypeCoverageImpl : HybridNitroTypeCoverageSpec {

    // ── Streams ───────────────────────────────────────────────────────────────
    private val _intStream = MutableSharedFlow<Long>(extraBufferCapacity = 64)
    private val _pointStream = MutableSharedFlow<TcPoint>(extraBufferCapacity = 64)
    override val intStream: Flow<Long> = _intStream
    override val pointStream: Flow<TcPoint> = _pointStream

    // ── Properties ────────────────────────────────────────────────────────────
    override var precision: Long = 0L
    override var tag: String = ""
    override var nullableRate: Double? = null

    // ── Primitives ────────────────────────────────────────────────────────────
    override fun echoInt(value: Long): Long = value
    override fun echoDouble(value: Double): Double = value
    override fun echoBool(value: Boolean): Boolean = value
    override fun echoString(value: String): String = value

    // ── Nullable ──────────────────────────────────────────────────────────────
    override fun echoNullableInt(value: Long?): Long = value ?: 0L
    override fun echoNullableDouble(value: Double?): Double = value ?: 0.0
    override fun echoNullableBool(value: Boolean?): Boolean = value ?: false
    override fun echoNullableString(value: String?): String = value ?: ""

    // ── Enum ──────────────────────────────────────────────────────────────────
    override fun echoStatus(value: TcStatus): TcStatus = value

    // ── Struct ────────────────────────────────────────────────────────────────
    override fun echoPoint(value: TcPoint): TcPoint = value

    // ── @HybridRecord ─────────────────────────────────────────────────────────
    override fun echoConfig(value: TcConfig): TcConfig = value

    // ── TypedData (zero-copy via DirectByteBuffer) ────────────────────────────
    override fun echoBytes(value: ByteArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size)
        buf.put(value); buf.flip(); return buf
    }

    override fun echoFloats(value: FloatArray): java.nio.ByteBuffer {
        val buf = java.nio.ByteBuffer.allocateDirect(value.size * 4)
            .order(java.nio.ByteOrder.nativeOrder())
        buf.asFloatBuffer().put(value); buf.rewind(); return buf
    }

    // ── Lists (async) ─────────────────────────────────────────────────────────
    override suspend fun echoIntList(value: Any?): List<Long> =
        if (value is List<*>) @Suppress("UNCHECKED_CAST") (value as List<Long>) else emptyList()

    override suspend fun echoDoubleList(value: Any?): List<Double> =
        if (value is List<*>) @Suppress("UNCHECKED_CAST") (value as List<Double>) else emptyList()

    override suspend fun echoStringList(value: Any?): List<String> =
        if (value is List<*>) @Suppress("UNCHECKED_CAST") (value as List<String>) else emptyList()

    // ── Async ─────────────────────────────────────────────────────────────────
    override suspend fun asyncDouble(value: Double): Double = value
    override suspend fun asyncString(value: String): String = value
    override suspend fun asyncInt(value: Long): Long = value

    // ── Stream control ────────────────────────────────────────────────────────
    override fun configureStream(from: Long, count: Long) {
        CoroutineScope(Dispatchers.Default).launch {
            for (i in 0 until count) {
                _intStream.emit(from + i)
                _pointStream.emit(TcPoint(x = (from + i).toDouble(), y = (from + i) * 0.5, z = 0.0))
            }
        }
    }
}
