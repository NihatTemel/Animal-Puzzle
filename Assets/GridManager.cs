using UnityEngine;

/// <summary>
/// Sahnede bir grid oluþturup her hücreye "gridNodePrefab" objesini spawnlar.
///
/// ÖNEMLÝ KURAL: Grid'in baþlangýç noktasý HER ZAMAN dünya uzayýnda
/// (X=0, Y=bu objenin kendi Y'si, Z=0) olur. Yani GridManager objesini
/// sahnede Y ekseninde yukarý/aþaðý taþýyarak grid'in yüksekliðini
/// ayarlayabilirsin, ama X/Z'si her zaman 0'dan baþlar ve oradan
/// +X, +Z yönünde geniþler.
///
/// KULLANIM:
/// 1) "Grid Node Prefab" alanýna kendi hazýrladýðýn yuvarlak node prefabýný sürükle.
/// 2) "Columns" (X ekseni hücre sayýsý) ve "Rows" (Z ekseni hücre sayýsý) gir - 4x4, 5x4 vs.
/// 3) "Cell Spacing" ile hücreler arasý mesafeyi ayarla (varsayýlan 1.1 -
///    1 birimlik bir küpün kenarýndan biraz uzun, hafif boþluklu dizilim için).
/// 4) Inspector'da bu component'in baþlýðýna SAÐ TIKLA -> "Grid Oluþtur".
///    Play moduna girmene gerek yok, Editor'da anýnda oluþturur.
///    Deðerleri her deðiþtirdiðinde tekrar "Grid Oluþtur"a bas; eski grid
///    otomatik temizlenip yenisi kurulur.
/// 5) "Generate On Start" iþaretliyse, Play moduna girildiðinde de
///    otomatik olarak (yeniden) oluþturulur.
/// </summary>
public class GridManager : MonoBehaviour
{
    [Header("Grid Boyutu")]
    [Tooltip("X ekseninde kaç hücre (sütun)")]
    public int columns = 4;
    [Tooltip("Z ekseninde kaç hücre (satýr)")]
    public int rows = 4;

    [Header("Hücre Ayarlarý")]
    [Tooltip("Hücreler arasý mesafe. Varsayýlan 1.1 - bir küpün (1 birim) " +
             "kenarýndan biraz uzun, böylece hücreler hafif boþluklu dizilir.")]
    public float cellSpacing = 1.1f;
    [Tooltip("Ýþaretliyse sütunlar SOL yöne doðru geniþler (varsayýlan: saða doðru)")]
    public bool invertColumnDirection = false;
    [Tooltip("Ýþaretliyse satýrlar farklý yöne doðru geniþler - ekranýnda " +
             "'aþaðý' beklediðin yönle ters çýkarsa bunu deðiþtir")]
    public bool invertRowDirection = false;

    [Header("Prefab")]
    [Tooltip("Her hücreye spawnlanacak obje (senin hazýrladýðýn grid node prefabý)")]
    public GameObject gridNodePrefab;

    [Header("Runtime")]
    [Tooltip("Play moduna girildiðinde grid otomatik (yeniden) oluþturulsun mu?")]
    public bool generateOnStart = true;

    private Transform nodesContainer;
    private GridNode[,] nodes;

    void Start()
    {
        if (generateOnStart)
            GenerateGrid();
    }

    /// <summary>
    /// Grid'in dünya uzayýndaki baþlangýç noktasý: bu GridManager objesinin
    /// KENDÝ TAM pozisyonu (X, Y, Z hepsi). Ýlk hücre (0,0) her zaman tam
    /// burada spawnlanýr, grid buradan saða ve aþaðý doðru geniþler.
    /// </summary>
    public Vector3 Origin => transform.position;

    [ContextMenu("Grid Oluþtur")]
    public void GenerateGrid()
    {
        ClearGrid();

        if (gridNodePrefab == null)
        {
            Debug.LogWarning("[GridManager] 'Grid Node Prefab' atanmamýþ, grid oluþturulamadý.");
            return;
        }

        EnsureContainer();

        nodes = new GridNode[columns, rows];

        float colSign = invertColumnDirection ? -1f : 1f;
        float rowSign = invertRowDirection ? -1f : 1f;

        // Önce satýr satýr (Z), her satýrda soldan saða (X) ilerleyerek spawnla.
        // Ýlk hücre (z=0, x=0) HER ZAMAN tam Origin noktasýnda olur.
        for (int z = 0; z < rows; z++)
        {
            for (int x = 0; x < columns; x++)
            {
                Vector3 pos = Origin + new Vector3(x * cellSpacing * colSign, 0f, z * cellSpacing * rowSign);

                GameObject nodeObj = Instantiate(gridNodePrefab, pos, Quaternion.identity, nodesContainer);
                nodeObj.name = $"GridNode_{x}_{z}";

                GridNode node = nodeObj.GetComponent<GridNode>();
                if (node == null)
                    node = nodeObj.AddComponent<GridNode>();

                node.gridX = x;
                node.gridZ = z;

                nodes[x, z] = node;
            }
        }

        Debug.Log($"[GridManager] {columns}x{rows} grid oluþturuldu. Origin={Origin}, spacing={cellSpacing}");
    }

    [ContextMenu("Grid Temizle")]
    public void ClearGrid()
    {
        Transform existing = transform.Find("GridNodes");
        if (existing == null) return;

        nodesContainer = existing;

        for (int i = nodesContainer.childCount - 1; i >= 0; i--)
        {
            GameObject child = nodesContainer.GetChild(i).gameObject;
            if (Application.isPlaying)
                Destroy(child);
            else
                DestroyImmediate(child);
        }
    }

    void EnsureContainer()
    {
        Transform existing = transform.Find("GridNodes");
        if (existing != null)
        {
            nodesContainer = existing;
            return;
        }

        GameObject containerObj = new GameObject("GridNodes");
        containerObj.transform.SetParent(transform);
        containerObj.transform.localPosition = Vector3.zero;
        nodesContainer = containerObj.transform;
    }

    /// <summary>Verilen grid koordinatýndaki node'u döndürür (yoksa null).</summary>
    public GridNode GetNode(int x, int z)
    {
        if (nodes == null || x < 0 || x >= columns || z < 0 || z >= rows) return null;
        return nodes[x, z];
    }

    /// <summary>Grid koordinatýný dünya pozisyonuna çevirir.</summary>
    public Vector3 GridToWorld(int x, int z)
    {
        float colSign = invertColumnDirection ? -1f : 1f;
        float rowSign = invertRowDirection ? -1f : 1f;
        return Origin + new Vector3(x * cellSpacing * colSign, 0f, z * cellSpacing * rowSign);
    }

    /// <summary>
    /// Verilen dünya pozisyonuna (Y'si önemsenmez, sadece X/Z) EN YAKIN grid
    /// node'unu döndürür. Grid düzenli/eþit aralýklý olduðu için brute-force
    /// arama yerine direkt matematikle en yakýn hücre indexini hesaplýyoruz.
    /// </summary>
    public GridNode GetNearestNode(Vector3 worldPos)
    {
        if (nodes == null || columns <= 0 || rows <= 0) return null;

        float colSign = invertColumnDirection ? -1f : 1f;
        float rowSign = invertRowDirection ? -1f : 1f;

        Vector3 local = worldPos - Origin;

        int x = Mathf.RoundToInt((local.x / cellSpacing) / colSign);
        int z = Mathf.RoundToInt((local.z / cellSpacing) / rowSign);

        x = Mathf.Clamp(x, 0, columns - 1);
        z = Mathf.Clamp(z, 0, rows - 1);

        return GetNode(x, z);
    }

    // Grid'i Scene view'da (obje seçiliyken) sarý noktalarla önizle
    void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.yellow;
        Vector3 origin = Origin;
        float colSign = invertColumnDirection ? -1f : 1f;
        float rowSign = invertRowDirection ? -1f : 1f;

        for (int x = 0; x < columns; x++)
        {
            for (int z = 0; z < rows; z++)
            {
                Vector3 pos = origin + new Vector3(x * cellSpacing * colSign, 0f, z * cellSpacing * rowSign);
                Gizmos.DrawWireSphere(pos, 0.15f);
            }
        }
    }
}