using UnityEngine;

// Bu script'i plane objesine ekle.
// Plane'in Scale'ini her deðiþtirdiðinde texture otomatik doðru 
// sayýda tekrarlanýr (gerilip bozulmaz).
[ExecuteAlways] // Editor'da, Play moduna girmeden de çalýþsýn diye
public class AutoTileTexture : MonoBehaviour
{
    [Header("Ayarlar")]
    [Tooltip("Unity'nin default Plane mesh'i 10x10 birimdir. Farklý bir mesh kullanýyorsan buraya onun gerçek boyutunu yaz.")]
    public float baseMeshSize = 10f;

    [Tooltip("Texture'ýn 1 tekrarýnýn (1 tile) kaç Unity biriminde görünmesini istiyorsun? Küçük deðer = texture daha sýk tekrar eder / daha yakýn görünür.")]
    public float tileWorldSize = 1f;

    private Renderer rend;
    private Vector3 lastScale;

    void OnEnable()
    {
        rend = GetComponent<Renderer>();
        UpdateTiling();
    }

    void Update()
    {
        // Sadece Scale deðiþtiðinde yeniden hesapla, gereksiz yere her frame iþlem yapma
        if (transform.localScale != lastScale)
        {
            UpdateTiling();
        }
    }

    void UpdateTiling()
    {
        if (rend == null) rend = GetComponent<Renderer>();
        if (rend == null || rend.sharedMaterial == null) return;

        Vector3 scale = transform.localScale;

        float tilingX = (scale.x * baseMeshSize) / tileWorldSize;
        float tilingZ = (scale.z * baseMeshSize) / tileWorldSize;

        // sharedMaterial kullanýyoruz ki Editor'da tüm instance'lar 
        // yerine sadece bu materyal güncellensin (Play modunda .material'a geçebilirsin)
        rend.sharedMaterial.mainTextureScale = new Vector2(tilingX, tilingZ);

        lastScale = scale;
    }
}