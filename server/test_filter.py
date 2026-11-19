import unittest
from server import classify
class Filters(unittest.TestCase):
    def test_upcoming(self):self.assertEqual(classify('Hakaton bo‘lib o‘tadi. Ro‘yxatdan o‘ting.'),'hakaton')
    def test_report(self):self.assertIsNone(classify('Hakaton bo‘lib o‘tdi. G‘oliblar taqdirlandi.'))
    def test_ads(self):self.assertIsNone(classify('Sotiladi. Arzon narxlar.'))
    def test_categories(self):
        for word,category in [('Tanlov','tanlov'),('Seminar','tadbir'),('Grant','grant'),('Olimpiada','musobaqa')]:
            self.assertEqual(classify(word+' uchun ariza qabul boshlandi'),category)
if __name__=='__main__':unittest.main()
