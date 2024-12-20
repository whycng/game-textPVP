import jieba
import sys

def segment_text(text):
    seg_list = jieba.cut(text)
    print(" ".join(seg_list))

if __name__ == "__main__":
    text = sys.argv[1]
    segment_text(text)