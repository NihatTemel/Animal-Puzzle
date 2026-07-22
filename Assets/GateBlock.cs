using UnityEngine;

/// <summary>
/// Bir renk kapýsý. SADECE kendi rengiyle (gateColor) eþleþen bir FreeDragBlock
/// bu objenin içinden geçebilir. Farklý renkteki bloklar için normal bir duvar
/// gibi davranýr (geçemez).
///
/// Kurulum:
/// - Bu objeye bir Collider ekle (Is Trigger KAPALI - normal, katý bir collider).
///   Trigger olmasýna gerek yok çünkü geçirgenlik kontrolünü FreeDragBlock
///   kendi çarpýþma mantýðýnda (renk kontrolüyle) yapýyor.
/// - Bu objeyi "Gates" (ya da tercih ettiðin) Layer'a ata.
/// - FreeDragBlock'larýn "Collision Mask" alanýna bu Layer'ý da ekle,
///   yoksa kapýyla hiç çarpýþma testi yapýlmaz (görünmez/etkisiz olur).
/// </summary>
public class GateBlock : MonoBehaviour
{
    [Tooltip("Bu kapýdan SADECE bu renkteki block geçebilir")]
    public BlockColor gateColor;
}