library utilities;

/** Creates a third list containing the content of the two lists.*/
List union(List aList, List bList) {
  List cList = new List();
  cList.addAll(aList);
  cList.addAll(bList);
  return cList;
}

/**
 * Moves an item in [list] from [fromIndex] to [toIndex].
 */
void moveTo(List list, int fromIndex, int toIndex) {
  if(list != null && fromIndex < list.length && toIndex < list.length && fromIndex != toIndex) {
    var tmp = list.removeAt(fromIndex);
    list.insert(toIndex, tmp);
  }
}

DateTime dateTimeFromUnixTimestamp(int seconds) => new DateTime.fromMillisecondsSinceEpoch(seconds*1000);

int unixTimestampFromDateTime(DateTime datetime) => datetime.millisecondsSinceEpoch~/1000;
