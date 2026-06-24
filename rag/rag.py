import os
import numpy as np
import pandas as pd
from google import genai
from google.genai import types
from google.cloud import bigquery

# 設定
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
PROJECT_ID = "mizuki-analytics"
DATASET = "dbt_mart"
TABLE = "mart_ltv_funnel"

# Geminiクライアント初期化
client = genai.Client(api_key=GEMINI_API_KEY)

def get_bq_data():
    """BigQueryからmart_ltv_funnelを取得"""
    bq_client = bigquery.Client(project=PROJECT_ID)
    query = f"""
    SELECT
        user_pseudo_id,
        member_rank,
        total_ltv,
        view_item_count,
        add_to_cart_count,
        purchase_count,
        view_to_cart_rate,
        cart_to_purchase_rate
    FROM `{PROJECT_ID}.{DATASET}.{TABLE}`
    """
    df = bq_client.query(query).to_dataframe()
    return df

def embed_text(text, task_type="retrieval_document"):
    """テキストをGemini Embeddingでベクトル化"""
    result = client.models.embed_content(
        model="gemini-embedding-001",
        contents=text,
        config=types.EmbedContentConfig(task_type=task_type)
    )
    return result.embeddings[0].values

def cosine_similarity(vec1, vec2):
    """コサイン類似度を計算"""
    v1 = np.array(vec1)
    v2 = np.array(vec2)
    return float(np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2)))

def build_context(df):
    """DataFrameを文字列リストに変換"""
    records = []
    for _, row in df.iterrows():
        text = (
            f"ユーザー: {row['user_pseudo_id']}, "
            f"会員ランク: {row['member_rank']}, "
            f"LTV: {row['total_ltv']:.0f}円, "
            f"商品閲覧: {row['view_item_count']}回, "
            f"カート追加: {row['add_to_cart_count']}回, "
            f"購入: {row['purchase_count']}回, "
            f"閲覧→カート率: {float(row['view_to_cart_rate']):.2%}, "
            f"カート→購入率: {float(row['cart_to_purchase_rate']):.2%}"
        )
        records.append(text)
    return records

def rag_query(question, records, record_embeddings, top_k=3):
    """RAGで質問に回答"""
    q_embedding = embed_text(question, task_type="retrieval_query")
    similarities = [cosine_similarity(q_embedding, emb) for emb in record_embeddings]
    top_indices = sorted(range(len(similarities)), key=lambda i: similarities[i], reverse=True)[:top_k]
    context = "\n".join([records[i] for i in top_indices])

    prompt = f"""
以下のマーケティングデータを参考に、質問に日本語で答えてください。

データ:
{context}

質問: {question}
"""
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt
    )
    return response.text

def main():
    print("BigQueryからデータを取得中...")
    df = get_bq_data()
    print(f"{len(df)}件のデータを取得しました")

    print("Embeddingを生成中...")
    records = build_context(df)
    record_embeddings = [embed_text(r) for r in records]
    print("Embedding完了")

    questions = [
        "Goldランクの会員のLTVはどのくらいですか？",
        "カートから購入への転換率が高いユーザーの特徴は？",
        "最もLTVが高いユーザーを教えてください"
    ]

    for q in questions:
        print(f"\n質問: {q}")
        answer = rag_query(q, records, record_embeddings)
        print(f"回答: {answer}")

if __name__ == "__main__":
    main()
