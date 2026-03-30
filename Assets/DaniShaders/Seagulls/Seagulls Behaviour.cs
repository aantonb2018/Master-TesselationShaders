using System.Linq;
using UnityEngine;


[RequireComponent(typeof(MeshFilter))]
public class SeagullsBehaviour : MonoBehaviour
{
    public int birdCount;
    public float radius;

    void Start()
    {
        CreatePointCloud();
    }

    void CreatePointCloud()
    {
        Mesh mesh = new Mesh();
        Vector3[] verts = new Vector3[birdCount];
        int[] indices = new int[birdCount];

        for (int i = 0; i < birdCount; i++)
        {
            verts[i] = Random.insideUnitSphere * radius;
            indices[i] = i;
        }

        mesh.vertices = verts;
        mesh.SetIndices(indices, MeshTopology.Points, 0);

        GetComponent<MeshFilter>().mesh = mesh;
        GetComponent<MeshRenderer>().material.SetFloat("_Size", 0.5f);
    }
}
