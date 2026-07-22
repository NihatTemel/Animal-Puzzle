using UnityEngine;

/// <summary>
/// Grid'deki her hücreye (node) GridManager tarafýndan OTOMATIK eklenir.
/// Hücrenin grid koordinatlarýný taþýr. Bu component'i prefab'a ELLE
/// eklemene gerek yok - GridManager, Instantiate ettikten sonra bunu
/// otomatik ekleyip (yoksa) deðerleri dolduruyor.
/// </summary>
public class GridNode : MonoBehaviour
{
    [HideInInspector] public int gridX;
    [HideInInspector] public int gridZ;
}