using UnityEngine;

/// <summary>
/// Grid henüz yok - sadece serbest sürükleme + duvar/block/gate çarpýþmasý.
/// Blocku tutup býraktýðýn yerde mouse'u XZ düzleminde takip eder,
/// ama duvarlarýn, baþka blocklarýn ve kendi renginde OLMAYAN gate'lerin
/// ÝÇÝNDEN geçemez. Y ekseni hiç deðiþmez.
/// </summary>
[RequireComponent(typeof(Collider))]
public class FreeDragBlock : MonoBehaviour
{
    [Header("Block Özellikleri")]
    [Tooltip("Bu block'un rengi. Sadece KENDÝ renginde olan gate'lerden geçebilir.")]
    public BlockColor color;

    [Header("Çarpýþma Ayarlarý")]
    [Tooltip("Çarpýþma testine dahil edilecek TÜM layer'lar: duvarlar + diðer bloklar + " +
             "gate'ler. Gate'ler özel olarak ele alýnýr (renk eþleþirse görmezden gelinir), " +
             "diðerleri (duvar, baþka block, yanlýþ renkli gate) her zaman engel sayýlýr.")]
    public LayerMask collisionMask;
    [Tooltip("Duvara tam yapýþmayý önlemek için küçük bir pay (titremeyi engeller)")]
    public float skin = 0.02f;

    [Header("Hareket Hýzý Sýnýrý")]
    [Tooltip("Block saniyede en fazla kaç birim hareket edebilir. Mouse pozisyonuna " +
             "DÝREKT eþitlemek yerine, ona doðru bu hýzla 'yaklaþýr'. Böylece hem " +
             "hýzlý/anormal mouse hareketlerinde tek frame'de büyük sýçrama imkansýz " +
             "hale gelir, hem de daha yumuþak bir 'takip ediyor' hissi oluþur. " +
             "Küçük deðer = daha yavaþ/yumuþak takip, büyük deðer = mouse'a daha yakýn anlýk takip.")]
    public float maxSpeed = 8f;

    [Header("Grid Snapping")]
    [Tooltip("Býrakýnca (mouse up) en yakýn grid node'unun X/Z'sine otursun mu?")]
    public bool snapToGrid = true;
    [Tooltip("Boþ býrakýlýrsa sahnedeki ilk GridManager otomatik bulunur.")]
    public GridManager gridManager;

    private Camera cam;
    private Plane dragPlane;
    private Vector3 grabOffset;
    private float baseY;
    private bool isDragging;
    private Vector3 halfExtents;
    private Collider ownCollider;

    void Start()
    {
        cam = Camera.main;
        baseY = transform.position.y;

        ownCollider = GetComponent<Collider>();
        halfExtents = ownCollider.bounds.extents;

        if (gridManager == null)
            gridManager = FindFirstObjectByType<GridManager>();
    }

    void OnMouseDown()
    {
        isDragging = true;
        dragPlane = new Plane(Vector3.up, transform.position);

        Vector3 hitPoint = GetMouseWorldPoint();
        grabOffset = transform.position - hitPoint;
    }

    void OnMouseDrag()
    {
        if (!isDragging) return;

        Vector3 hitPoint = GetMouseWorldPoint();
        Vector3 desiredPos = hitPoint + grabOffset;
        desiredPos.y = baseY; // Y hiç deðiþmesin

        // --- MOUSE POZÝSYONUNA DÝREKT EÞÝTLEMÝYORUZ ---
        // X ve Z eksenlerinin hýz sýnýrýný BÝRBÝRÝNDEN BAÐIMSIZ uyguluyoruz.
        // Neden: tek bir 3D vektör üzerinden sýnýrlarsak, bir eksen duvarla
        // engellenince (örn. X), hareket "bütçesinin" çoðu o engellenmiþ yöne
        // harcanýr ve diðer eksen (Z, duvara paralel kayma) yavaþlar/takýlýr gibi
        // hissettirir. Ayrý ayrý sýnýrlayýnca, duvara yaslanýrken bile duvara
        // paralel kayma tam hýzýnda devam edebiliyor.
        Vector3 current = transform.position;
        float maxStep = maxSpeed * Time.deltaTime;

        float dx = Mathf.Clamp(desiredPos.x - current.x, -maxStep, maxStep);
        float dz = Mathf.Clamp(desiredPos.z - current.z, -maxStep, maxStep);

        Vector3 stepTarget = new Vector3(current.x + dx, current.y, current.z + dz);

        transform.position = ResolveCollision(current, stepTarget);
    }

    void OnMouseUp()
    {
        isDragging = false;

        if (snapToGrid && gridManager != null)
        {
            GridNode nearest = gridManager.GetNearestNode(transform.position);
            if (nearest != null)
            {
                Vector3 snapPos = nearest.transform.position;
                snapPos.y = baseY; // Y hiç deðiþmesin
                transform.position = snapPos;
            }
        }
    }

    Vector3 GetMouseWorldPoint()
    {
        Ray ray = cam.ScreenPointToRay(Input.mousePosition);
        if (dragPlane.Raycast(ray, out float enter))
            return ray.GetPoint(enter);
        return transform.position;
    }

    /// <summary>
    /// current -> desired arasý giderken bir engele çarpýyorsa X ve Z eksenlerini
    /// AYRI AYRI dener. Böylece bir engele çapraz yaklaþýrken ona paralel
    /// "kayarak" hareket devam eder, tamamen kilitlenmez.
    /// SONDA bir güvenlik kontrolü var: sweep bir þekilde kaçýrýrsa bile,
    /// sonuç pozisyon hâlâ GERÇEK bir engelle iç içeyse hareketi tamamen iptal ederiz.
    /// </summary>
    Vector3 ResolveCollision(Vector3 current, Vector3 desired)
    {
        Vector3 afterX = MoveAxis(current, new Vector3(desired.x - current.x, 0f, 0f), "X");
        Vector3 afterZ = MoveAxis(afterX, new Vector3(0f, 0f, desired.z - current.z), "Z");

        // --- GÜVENLÝK AÐI: sweep kaçýrmýþ olsa bile son pozisyonu doðrula ---
        Vector3 safetyExtents = halfExtents - Vector3.one * (skin * 0.5f);
        Collider[] overlaps = Physics.OverlapBox(afterZ, safetyExtents, transform.rotation, collisionMask);
        foreach (var overlap in overlaps)
        {
            if (IsIgnorable(overlap)) continue; // kendi collider'ýmýz ya da eþleþen renkte gate

            Debug.LogWarning($"[FREEDRAG] GÜVENLÝK AÐI TETÝKLENDÝ! afterZ={afterZ} '{overlap.name}' ile iç içe, current'a ({current}) geri dönülüyor.");
            return current;
        }

        return afterZ;
    }

    /// <summary>
    /// 'from' noktasýndan 'delta' kadar (tek eksende) hareket etmeye çalýþýr.
    /// BoxCastALL ile yol üzerindeki TÜM çarpýþmalarý tarar (tek en yakýn hit deðil),
    /// çünkü yoldaki ilk þey eþleþen renkte bir gate olabilir - onu görmezden geçip
    /// arkasýnda GERÇEK bir engel (duvar/baþka block/yanlýþ renk gate) var mý diye
    /// bakmamýz gerekiyor.
    /// Engele deðmeden 'skin' kadar ÖNCE durur (tunneling yok, ve her zaman gerçek
    /// bir boþluk býrakýr - aksi halde duvara paralel kayma kilitlenebiliyor).
    /// </summary>
    Vector3 MoveAxis(Vector3 from, Vector3 delta, string axisLabel)
    {
        float distance = delta.magnitude;
        if (distance < 0.0001f) return from;

        Vector3 direction = delta.normalized;

        RaycastHit[] hits = Physics.BoxCastAll(from, halfExtents, direction, transform.rotation,
                                                distance, collisionMask);

        // En yakýndan en uzaða sýrala
        System.Array.Sort(hits, (a, b) => a.distance.CompareTo(b.distance));

        foreach (var hit in hits)
        {
            if (IsIgnorable(hit.collider)) continue; // kendi collider'ýmýz ya da eþleþen renkte gate

            // Buraya geldiysek: gerçek bir engel (duvar / baþka block / yanlýþ renk gate)
            Debug.Log($"[FREEDRAG] MoveAxis({axisLabel}) ENGELLENDÝ - obj={hit.collider.name}, hitDistance={hit.distance:F3}");
            float safeDistance = Mathf.Max(0f, hit.distance - skin);
            return from + direction * safeDistance;
        }

        // Yolda gerçek bir engel yok (belki eþleþen renkte gate'ler vardý, hepsi geçildi)
        return from + delta;
    }

    /// <summary>
    /// Bu collider'ý çarpýþma amaçlý yok sayabilir miyiz?
    /// - Kendi collider'ýmýzsa: evet (kendi kendine çarpma olmasýn).
    /// - Bir GateBlock ise VE rengi bizimkiyle eþleþiyorsa VE ayný obje ayný
    ///   zamanda bir FreeDragBlock DEÐÝLSE: evet (bu kapýdan geçebiliriz).
    /// - Aksi halde (duvar / baþka block / yanlýþ renk gate / hem block hem
    ///   gate olarak yanlýþlýkla iþaretlenmiþ bir obje): hayýr, gerçek bir engel.
    ///
    /// Son kural bir güvenlik aðý: bir obje yanlýþlýkla hem FreeDragBlock hem
    /// GateBlock taþýyorsa (örn. Inspector'da yanlýþlýkla eklenmiþse), onu
    /// ASLA gate olarak saymayýz - her zaman gerçek/katý bir engel sayýlýr.
    /// </summary>
    bool IsIgnorable(Collider other)
    {
        if (other == ownCollider) return true;

        GateBlock gate = other.GetComponent<GateBlock>();
        if (gate != null && gate.gateColor == color)
        {
            bool isAlsoABlock = other.GetComponent<FreeDragBlock>() != null;
            if (isAlsoABlock)
            {
                Debug.LogWarning($"[FREEDRAG] '{other.name}' hem FreeDragBlock hem GateBlock taþýyor - " +
                                  "bu YANLIÞ bir kurulum, gate olarak SAYILMADI. GateBlock component'ini bu objeden kaldýr.");
                return false;
            }
            return true;
        }

        return false;
    }
}