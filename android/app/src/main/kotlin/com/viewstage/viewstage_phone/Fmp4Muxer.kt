package com.viewstage.viewstage_phone

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer

/**
 * fMP4 Box 构建器
 * 生成 MSE 兼容的 init segment 和 video segment
 */
object Fmp4Muxer {

    private var sequenceNumber = 1

    /**
     * 构建 init segment (ftyp + moov)
     * 包含 SPS/PPS 参数集，连接后首先发送一次
     */
    fun buildInitSegment(sps: ByteArray, pps: ByteArray): ByteArray {
        val baos = ByteArrayOutputStream()
        val dos = DataOutputStream(baos)

        // ftyp box
        writeFtyp(dos)

        // moov box
        writeMoov(dos, sps, pps)

        dos.flush()
        return baos.toByteArray()
    }

    /**
     * 构建 video segment (moof + mdat)
     * 每个编码帧调用一次
     */
    fun buildVideoSegment(nalu: ByteArray, isKeyFrame: Boolean, dts: Long, pts: Long): ByteArray {
        val baos = ByteArrayOutputStream()
        val dos = DataOutputStream(baos)

        // moof box
        writeMoof(dos, nalu.size, isKeyFrame, dts, pts)

        // mdat box
        writeMdat(dos, nalu)

        dos.flush()
        sequenceNumber++
        return baos.toByteArray()
    }

    fun reset() {
        sequenceNumber = 1
    }

    // ===== ftyp =====
    private fun writeFtyp(dos: DataOutputStream) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // major_brand = isom
        inner.writeBytes("isom")
        // minor_version
        inner.writeInt(0x200)
        // compatible_brands
        inner.writeBytes("isom")
        inner.writeBytes("iso2")
        inner.writeBytes("avc1")
        inner.writeBytes("mp41")

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size) // size
        dos.writeBytes("ftyp")      // type
        dos.write(data)
    }

    // ===== moov =====
    private fun writeMoov(dos: DataOutputStream, sps: ByteArray, pps: ByteArray) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // mvhd
        writeMvhd(inner)

        // trak
        writeTrak(inner, sps, pps)

        // mvex
        writeMvex(inner)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("moov")
        dos.write(data)
    }

    // ===== mvhd =====
    private fun writeMvhd(dos: DataOutputStream) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0, flags = 0
        inner.writeByte(0)
        inner.write(byteArrayOf(0, 0, 0))
        // creation_time
        inner.writeInt(0)
        // modification_time
        inner.writeInt(0)
        // timescale = 1000 (ms)
        inner.writeInt(1000)
        // duration = 0 (live stream)
        inner.writeInt(0)
        // rate = 1.0 (0x00010000)
        inner.writeInt(0x00010000)
        // volume = 1.0 (0x0100)
        inner.writeShort(0x0100)
        // reserved (10 bytes)
        inner.write(ByteArray(10))
        // matrix (36 bytes) - identity matrix
        inner.writeInt(0x00010000); inner.writeInt(0); inner.writeInt(0)
        inner.writeInt(0); inner.writeInt(0x00010000); inner.writeInt(0)
        inner.writeInt(0); inner.writeInt(0); inner.writeInt(0x40000000)
        // pre_defined (24 bytes)
        inner.write(ByteArray(24))
        // next_track_ID
        inner.writeInt(2)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("mvhd")
        dos.write(data)
    }

    // ===== trak =====
    private fun writeTrak(dos: DataOutputStream, sps: ByteArray, pps: ByteArray) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // tkhd
        writeTkhd(inner)

        // mdia
        writeMdia(inner, sps, pps)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("trak")
        dos.write(data)
    }

    // ===== tkhd =====
    private fun writeTkhd(dos: DataOutputStream) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0, flags = 0x000003 (track_enabled | track_in_movie)
        inner.writeByte(0)
        inner.write(byteArrayOf(0, 0, 3))
        // creation_time
        inner.writeInt(0)
        // modification_time
        inner.writeInt(0)
        // track_ID = 1
        inner.writeInt(1)
        // reserved
        inner.writeInt(0)
        // duration = 0
        inner.writeInt(0)
        // reserved (8 bytes)
        inner.write(ByteArray(8))
        // layer = 0
        inner.writeShort(0)
        // alternate_group = 0
        inner.writeShort(0)
        // volume = 0 (video)
        inner.writeShort(0)
        // reserved
        inner.writeShort(0)
        // matrix (36 bytes)
        inner.writeInt(0x00010000); inner.writeInt(0); inner.writeInt(0)
        inner.writeInt(0); inner.writeInt(0x00010000); inner.writeInt(0)
        inner.writeInt(0); inner.writeInt(0); inner.writeInt(0x40000000)
        // width (16.16 fixed point)
        inner.writeInt(1920 shl 16)
        // height (16.16 fixed point)
        inner.writeInt(1080 shl 16)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("tkhd")
        dos.write(data)
    }

    // ===== mdia =====
    private fun writeMdia(dos: DataOutputStream, sps: ByteArray, pps: ByteArray) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // mdhd
        writeMdhd(inner)

        // hdlr
        writeHdlr(inner)

        // minf
        writeMinf(inner, sps, pps)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("mdia")
        dos.write(data)
    }

    // ===== mdhd =====
    private fun writeMdhd(dos: DataOutputStream) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0, flags = 0
        inner.writeByte(0)
        inner.write(byteArrayOf(0, 0, 0))
        // creation_time
        inner.writeInt(0)
        // modification_time
        inner.writeInt(0)
        // timescale = 90000 (video clock)
        inner.writeInt(90000)
        // duration = 0
        inner.writeInt(0)
        // language (packed ISO-639-2) = und
        inner.writeShort(0x756E)
        // pre_defined
        inner.writeShort(0)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("mdhd")
        dos.write(data)
    }

    // ===== hdlr =====
    private fun writeHdlr(dos: DataOutputStream) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0, flags = 0
        inner.writeByte(0)
        inner.write(byteArrayOf(0, 0, 0))
        // pre_defined
        inner.writeInt(0)
        // handler_type = vide
        inner.writeBytes("vide")
        // reserved (12 bytes)
        inner.write(ByteArray(12))
        // name = "VideoHandler\0"
        inner.writeBytes("VideoHandler")
        inner.writeByte(0)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("hdlr")
        dos.write(data)
    }

    // ===== minf =====
    private fun writeMinf(dos: DataOutputStream, sps: ByteArray, pps: ByteArray) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // vmhd
        writeVmhd(inner)

        // dinf
        writeDinf(inner)

        // stbl
        writeStbl(inner, sps, pps)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("minf")
        dos.write(data)
    }

    // ===== vmhd =====
    private fun writeVmhd(dos: DataOutputStream) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0, flags = 1
        inner.writeByte(0)
        inner.write(byteArrayOf(0, 0, 1))
        // graphicsmode = 0
        inner.writeShort(0)
        // opcolor (6 bytes)
        inner.write(ByteArray(6))

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("vmhd")
        dos.write(data)
    }

    // ===== dinf =====
    private fun writeDinf(dos: DataOutputStream) {
        val drefData = ByteArrayOutputStream()
        val drefInner = DataOutputStream(drefData)

        // version = 0, flags = 0
        drefInner.writeByte(0)
        drefInner.write(byteArrayOf(0, 0, 0))
        // entry_count = 1
        drefInner.writeInt(1)

        // url entry: version = 0, flags = 1 (self-contained)
        drefInner.writeInt(12) // size
        drefInner.writeBytes("url ")
        drefInner.writeByte(0)
        drefInner.write(byteArrayOf(0, 0, 1))

        drefInner.flush()
        val drefBoxData = drefData.toByteArray()

        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        inner.writeInt(8 + drefBoxData.size)
        inner.writeBytes("dref")
        inner.write(drefBoxData)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("dinf")
        dos.write(data)
    }

    // ===== stbl =====
    private fun writeStbl(dos: DataOutputStream, sps: ByteArray, pps: ByteArray) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // stsd
        writeStsd(inner, sps, pps)

        // stts (time-to-sample) - empty
        writeEmptyBox(inner, "stts")

        // stsc (sample-to-chunk) - empty
        writeEmptyBox(inner, "stsc")

        // stsz (sample size) - empty
        writeEmptyBox(inner, "stsz")

        // stco (chunk offset) - empty
        writeEmptyBox(inner, "stco")

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("stbl")
        dos.write(data)
    }

    // ===== stsd =====
    private fun writeStsd(dos: DataOutputStream, sps: ByteArray, pps: ByteArray) {
        val entryData = ByteArrayOutputStream()
        val entryInner = DataOutputStream(entryData)

        // avc1 sample entry
        writeAvc1(entryInner, sps, pps)

        entryInner.flush()
        val entry = entryData.toByteArray()

        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0, flags = 0
        inner.writeByte(0)
        inner.write(byteArrayOf(0, 0, 0))
        // entry_count = 1
        inner.writeInt(1)
        // avc1 entry
        inner.write(entry)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("stsd")
        dos.write(data)
    }

    // ===== avc1 =====
    private fun writeAvc1(dos: DataOutputStream, sps: ByteArray, pps: ByteArray) {
        val avccData = ByteArrayOutputStream()
        val avccInner = DataOutputStream(avccData)

        // avcC box
        writeAvcC(avccInner, sps, pps)

        avccInner.flush()
        val avcc = avccData.toByteArray()

        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // reserved (6 bytes)
        inner.write(ByteArray(6))
        // data_reference_index = 1
        inner.writeShort(0)
        inner.writeShort(1)
        // pre_defined
        inner.writeShort(0)
        // reserved
        inner.writeShort(0)
        // pre_defined (12 bytes)
        inner.write(ByteArray(12))
        // width
        inner.writeShort(1920)
        // height
        inner.writeShort(1080)
        // horizresolution = 72 dpi (0x00480000)
        inner.writeInt(0x00480000)
        // vertresolution = 72 dpi (0x00480000)
        inner.writeInt(0x00480000)
        // reserved
        inner.writeInt(0)
        // frame_count = 1
        inner.writeShort(1)
        // compressorname (32 bytes)
        val compressorName = ByteArray(32)
        compressorName[0] = 0 // length prefix
        inner.write(compressorName)
        // depth = 0x0018
        inner.writeShort(0x0018)
        // pre_defined = -1
        inner.writeShort(-1)

        // avcC box
        inner.write(avcc)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("avc1")
        dos.write(data)
    }

    // ===== avcC =====
    private fun writeAvcC(dos: DataOutputStream, sps: ByteArray, pps: ByteArray) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // configurationVersion = 1
        inner.writeByte(1)
        // AVCProfileIndication (from SPS byte 1)
        inner.writeByte(sps[1].toInt() and 0xFF)
        // profile_compatibility (from SPS byte 2)
        inner.writeByte(sps[2].toInt() and 0xFF)
        // AVCLevelIndication (from SPS byte 3)
        inner.writeByte(sps[3].toInt() and 0xFF)
        // lengthSizeMinusOne = 3 (4 bytes NAL length)
        inner.writeByte(0xFF)
        // numOfSequenceParameterSets = 1
        inner.writeByte(0xE1)
        // SPS
        inner.writeShort(sps.size)
        inner.write(sps)
        // numOfPictureParameterSets = 1
        inner.writeByte(1)
        // PPS
        inner.writeShort(pps.size)
        inner.write(pps)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("avcC")
        dos.write(data)
    }

    // ===== mvex =====
    private fun writeMvex(dos: DataOutputStream) {
        val trexData = ByteArrayOutputStream()
        val trexInner = DataOutputStream(trexData)

        // version = 0, flags = 0
        trexInner.writeByte(0)
        trexInner.write(byteArrayOf(0, 0, 0))
        // track_ID = 1
        trexInner.writeInt(1)
        // default_sample_description_index = 1
        trexInner.writeInt(1)
        // default_sample_duration = 0
        trexInner.writeInt(0)
        // default_sample_size = 0
        trexInner.writeInt(0)
        // default_sample_flags = 0
        trexInner.writeInt(0)

        trexInner.flush()
        val trex = trexData.toByteArray()

        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        inner.writeInt(8 + trex.size)
        inner.writeBytes("trex")
        inner.write(trex)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("mvex")
        dos.write(data)
    }

    // ===== moof =====
    private fun writeMoof(dos: DataOutputStream, sampleSize: Int, isKeyFrame: Boolean, dts: Long, pts: Long) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // mfhd
        writeMfhd(inner)

        // traf
        writeTraf(inner, sampleSize, isKeyFrame, dts, pts)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("moof")
        dos.write(data)
    }

    // ===== mfhd =====
    private fun writeMfhd(dos: DataOutputStream) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0, flags = 0
        inner.writeByte(0)
        inner.write(byteArrayOf(0, 0, 0))
        // sequence_number
        inner.writeInt(sequenceNumber)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("mfhd")
        dos.write(data)
    }

    // ===== traf =====
    private fun writeTraf(dos: DataOutputStream, sampleSize: Int, isKeyFrame: Boolean, dts: Long, pts: Long) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // tfhd
        writeTfhd(inner)

        // tfdt
        writeTfdt(inner, dts)

        // trun
        writeTrun(inner, sampleSize, isKeyFrame, pts - dts)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("traf")
        dos.write(data)
    }

    // ===== tfhd =====
    private fun writeTfhd(dos: DataOutputStream) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0, flags = 0x020000 (default-sample-duration-present) |
        // 0x010000 (default-sample-size-present) | 0x000800 (default-sample-flags-present)
        inner.writeByte(0)
        inner.write(byteArrayOf(0x02, 0x00, 0x00))
        // track_ID = 1
        inner.writeInt(1)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("tfhd")
        dos.write(data)
    }

    // ===== tfdt =====
    private fun writeTfdt(dos: DataOutputStream, dts: Long) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 1 (64-bit time)
        inner.writeByte(1)
        inner.write(byteArrayOf(0, 0, 0))
        // baseMediaDecodeTime
        inner.writeLong(dts)

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("tfdt")
        dos.write(data)
    }

    // ===== trun =====
    private fun writeTrun(dos: DataOutputStream, sampleSize: Int, isKeyFrame: Boolean, compositionTimeOffset: Long) {
        val boxData = ByteArrayOutputStream()
        val inner = DataOutputStream(boxData)

        // version = 0
        // flags: 0x000001 (data-offset-present) | 0x000100 (sample-duration-present) |
        //        0x000200 (sample-size-present) | 0x000800 (sample-flags-present) |
        //        0x001000 (sample-composition-time-offsets-present)
        val flags = 0x000001 or 0x000100 or 0x000200 or 0x000800 or 0x001000
        inner.writeByte(0)
        inner.write(byteArrayOf(
            ((flags shr 16) and 0xFF).toByte(),
            ((flags shr 8) and 0xFF).toByte(),
            (flags and 0xFF).toByte()
        ))

        // sample_count = 1
        inner.writeInt(1)
        // data_offset (will be filled: moof size + 8 for mdat header)
        // moof: mfhd(16) + traf(tfhd(16) + tfdt(20) + trun(28)) = 80
        // But we need to calculate actual size
        inner.writeInt(0) // placeholder, will be patched

        // sample_duration = 3000 (30fps at 90000 timescale = 3000 ticks per frame)
        inner.writeInt(3000)
        // sample_size
        inner.writeInt(sampleSize)
        // sample_flags
        val sampleFlags = if (isKeyFrame) 0x02000000 else 0x01010000
        inner.writeInt(sampleFlags)
        // sample_composition_time_offset
        inner.writeInt(compositionTimeOffset.toInt())

        inner.flush()
        val data = boxData.toByteArray()

        dos.writeInt(8 + data.size)
        dos.writeBytes("trun")
        dos.write(data)
    }

    // ===== mdat =====
    private fun writeMdat(dos: DataOutputStream, nalu: ByteArray) {
        dos.writeInt(8 + nalu.size)
        dos.writeBytes("mdat")
        dos.write(nalu)
    }

    // ===== helper =====
    private fun writeEmptyBox(dos: DataOutputStream, type: String) {
        // version = 0, flags = 0, entry_count = 0
        val data = ByteArray(4) // version + flags
        dos.writeInt(8 + 4 + 4 + data.size) // size
        dos.writeBytes(type)
        dos.write(data)
        dos.writeInt(0) // entry_count
    }

    private fun DataOutputStream.writeBytes(s: String) {
        write(s.toByteArray(Charsets.US_ASCII))
    }
}
