using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GrassGenerator : MonoBehaviour
{
    public Mesh grassMesh;
    public int subMeshIndex = 0;
    public Material grassMaterial;
    public int GrassCountPerRaw = 150;//ÿ�вݵ�����
    public DepthTextureGenerator depthTextureGenerator;
    public ComputeShader compute;//�޳���ComputeShader

    int m_grassCount;
    int kernel;
    Camera mainCamera;

    ComputeBuffer argsBuffer;
    ComputeBuffer grassMatrixBuffer;//���вݵ������������
    ComputeBuffer cullResultBuffer;//�޳���Ľ��

    public Vector2 positionJitterRange = new Vector2(-0.4f, 0.4f); // ÿ����XZƽ�����ƫ�Ƶķ�Χ���ף�
    public Vector2 rotationYRange = new Vector2(0f, 360f);         // ��Y�����ת��Χ���ȣ�
    public Vector2 uniformScaleRange = new Vector2(1.0f, 1.0f);
    public int randomSeed = 12345;

    uint[] args = new uint[5] { 0, 0, 0, 0, 0 };

    int cullResultBufferId, vpMatrixId, positionBufferId, hizTextureId;

    static uint Hash_u32(uint x)
    {
        x ^= x >> 16; x *= 0x7feb352d; x ^= x >> 15; x *= 0x846ca68b; x ^= x >> 16;
        return x;
    }

    static float Hash01(int i, int j, int seed, int stream = 0)
    {
        uint h = (uint)(i * 374761393u) ^ (uint)(j * 668265263u) ^ (uint)(seed) ^ (uint)(stream * 0x9E3779B9u);
        return (Hash_u32(h) & 0x00FFFFFF) / (float)0x01000000; // 24bit -> [0,1)
    }

    static float RandRange(float min, float max, float r01) => min + (max - min) * r01;

    void Start()
    {
        m_grassCount = GrassCountPerRaw * GrassCountPerRaw;
        mainCamera = Camera.main;

        if(grassMesh != null) {
            args[0] = grassMesh.GetIndexCount(subMeshIndex);
            args[2] = grassMesh.GetIndexStart(subMeshIndex);
            args[3] = grassMesh.GetBaseVertex(subMeshIndex);
        }

        InitComputeBuffer();
        InitGrassPosition();
        InitComputeShader();
    }

    void InitComputeShader() {
        kernel = compute.FindKernel("GrassCulling");
        compute.SetInt("grassCount", m_grassCount);
        compute.SetInt("depthTextureSize", depthTextureGenerator.depthTextureSize);
        compute.SetBool("isOpenGL", Camera.main.projectionMatrix.Equals(GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, false)));
        compute.SetBuffer(kernel, "grassMatrixBuffer", grassMatrixBuffer);
        
        cullResultBufferId = Shader.PropertyToID("cullResultBuffer");
        vpMatrixId = Shader.PropertyToID("vpMatrix");
        hizTextureId = Shader.PropertyToID("hizTexture");
        positionBufferId = Shader.PropertyToID("positionBuffer");
    }

    void InitComputeBuffer() {
        if(grassMatrixBuffer != null) return;
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        argsBuffer.SetData(args);
        grassMatrixBuffer = new ComputeBuffer(m_grassCount, sizeof(float) * 16);
        cullResultBuffer = new ComputeBuffer(m_grassCount, sizeof(float) * 16, ComputeBufferType.Append);
    }

    void Update()
    {
        compute.SetTexture(kernel, hizTextureId, depthTextureGenerator.depthTexture);
        compute.SetMatrix(vpMatrixId, GL.GetGPUProjectionMatrix(mainCamera.projectionMatrix, false) * mainCamera.worldToCameraMatrix);
        cullResultBuffer.SetCounterValue(0);
        compute.SetBuffer(kernel, cullResultBufferId, cullResultBuffer);
        compute.Dispatch(kernel, 1 + m_grassCount / 640, 1, 1);
        grassMaterial.SetBuffer(positionBufferId, cullResultBuffer);

        //��ȡʵ��Ҫ��Ⱦ������
        ComputeBuffer.CopyCount(cullResultBuffer, argsBuffer, sizeof(uint));
        Graphics.DrawMeshInstancedIndirect(grassMesh, subMeshIndex, grassMaterial, new Bounds(Vector3.zero, new Vector3(100.0f, 100.0f, 100.0f)), argsBuffer);
    }

    //��ȡÿ���ݵ������������
    void InitGrassPosition() {
        const int padding = 2;
        int width = (100 - padding * 2);
        int widthStart = -width / 2;
        float step = (float)width / GrassCountPerRaw;
        Matrix4x4[] grassMatrixs = new Matrix4x4[m_grassCount];
        for(int i = 0; i < GrassCountPerRaw; i++) {
            for(int j = 0; j < GrassCountPerRaw; j++) {
                Vector2 xz = new Vector2(widthStart + step * i, widthStart + step * j);
                Vector3 basePos = new Vector3(xz.x, GetGroundHeight(xz), xz.y);

                // ---- ȷ���������Ϊÿ����������������� ----
                float rPosX = Hash01(i, j, randomSeed, 0);
                float rPosZ = Hash01(i, j, randomSeed, 1);
                float rRotY = Hash01(i, j, randomSeed, 2);
                float rScale = Hash01(i, j, randomSeed, 3);

                // ƫ�ƣ���XZƽ���ڣ�
                float jx = RandRange(positionJitterRange.x, positionJitterRange.y, rPosX);
                float jz = RandRange(positionJitterRange.x, positionJitterRange.y, rPosZ);
                Vector3 jitteredPos = new Vector3(basePos.x + jx, basePos.y, basePos.z + jz);

                // �ٴ����أ���ѡ�������������ƫ�ƺ����²ɸ߶ȣ�
                jitteredPos.y = GetGroundHeight(new Vector2(jitteredPos.x, jitteredPos.z));

                // ��Y�����ת
                float rotY = RandRange(rotationYRange.x, rotationYRange.y, rRotY);
                Quaternion rot = Quaternion.Euler(0f, rotY, 0f);

                // �ȱ����ţ���ѡ��
                float s = RandRange(uniformScaleRange.x, uniformScaleRange.y, rScale);
                Vector3 scale = new Vector3(s, s, s);

                grassMatrixs[i * GrassCountPerRaw + j] = Matrix4x4.TRS(jitteredPos, rot, scale);
            }
        }
        grassMatrixBuffer.SetData(grassMatrixs);
    }

    //ͨ��Raycast����ݵĸ߶�
    float GetGroundHeight(Vector2 xz) {
        RaycastHit hit;
        if(Physics.Raycast(new Vector3(xz.x, 10, xz.y), Vector3.down, out hit, 20)) {
            return 10 - hit.distance;
        }
        return 0;
    }

    void OnDisable() {
        grassMatrixBuffer?.Release();
        grassMatrixBuffer = null;

        cullResultBuffer?.Release();
        cullResultBuffer = null;

        argsBuffer?.Release();
        argsBuffer = null;
    }
}
